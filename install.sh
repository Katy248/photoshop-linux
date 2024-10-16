#!/usr/bin/env bash

# This work and script was adapted by the work of user LinSoftWin. If it wasn't for him - it wouldn't have happened.
# This script downloads a PIRATE version of Photoshop, because it is not possible to run the actual version from Adobe Creative Cloud.
# Use it at your own risk. The license applies only to the files in this repository.
# I am not responsible for any other files downloaded from other links using the script.
# If the link becomes inactive - it will be replaced by another hosting. Checksums of uploaded files will also be updated.

# TODO
# - Indicate download progress
# - Maybe use `aria2` for downloading files?
# - Multi distro dependencies installer
# - Implement logging adequately

# In case the user does not use the XDG Base Directory Specification
# https://specifications.freedesktop.org/basedir-spec/latest
XDG_DATA_HOME="$HOME/.local/share"

#                            LOGGING SYSTEM
# #####################################################################
#

BLUE="\e[1;34m"   # Blue
RED="\e[1;31m"    # Red
YELLOW="\e[1;33m" # Yellow
GREEN="\e[1;32m"  # Green
RESET="\e[0m"     # Reset colors

LOG="${BLUE}[LOG]${RESET}"
WARNING="${YELLOW}[WARNING]${RESET}"
ERORR="${RED}[ERROR]${RESET}"
SUCCES="${GREEN}[SUCCES]${RESET}"
CHECK="${GREEN}[CHECK]${RESET}"

#						CHECKS & OTHER FUNCTIONS
# ###################################################################
#

# Photoshop URL
PHOTOSHOP_URL="https://spyderrock.com/kMnq2220-AdobePhotoshop2021.xz"

# sha256 checksum
CHECKSUM="8321b969161f2d2ad736067320d493c5b6ae579eaab9400cd1fda6871af2c033"

LAUNCHER="$HOME/.local/bin/photoshop.sh"
LOCAL_ARCHIVE=""
ICON=""

# Identifier of current OS
OS_ID=$(./get-os-id.sh)

trap on_interrupt SIGINT

on_interrupt() {
	trap "exit 1" SIGINT

	echo -e "\n$WARNING User intrrupt!"

	if [ -d "$INSTALL_PATH" ]; then
		while true; do
			read -p "$(echo -e "$YELLOW")[WARNING]$(echo -e "$RESET") Do you want to $(echo -e "$RED")delete$(echo -e "$RESET") the just created wine prefix? (yes/no): " answer

			case "$answer" in
			[Yy]es | y)
				if rm -rf "${INSTALL_PATH:?}"; then
					exit 0
				else
					echo -e "$ERORR The last command ended with an error."
					exit 1
				fi
				;;
			[Nn]o | n)
				exit 0
				;;
			*)
				echo -e "$WARNING Invalid input!"
				;;
			esac
		done
	else
		exit 1
	fi
}

get_help() {
	echo "Usage: ./install.sh [options...] <absolute path>"
	echo "  -a    Use already existing Photoshop.tar.xz"
	echo "  -i    Install Photoshop"
	echo "  -h    Show this help"
}

# soon
print_error() {
	local message=$1
	echo -e "${ERORR} ${message}" >&2
}

print_log() {
	local message=$1
	echo -e "${LOG} ${message}"
}

print_warn() {
	local message=$1
	echo -e "${WARNING} ${message}" >&2
}

# Not used yet
ask_user() {
	local message=$1
	echo -e "${WARNING} ${message}"
	while true; do
		read -p "([Y]es/[N]o): " answer

		case "$answer" in
		[Yy]es | [Yy])
			return 0
			;;
		[Nn]o | [Nn])
			return 1
			;;

		*)
			echo "Invalid input, try again"
			;;
		esac
	done
}

# Imagemagick is needed in case you are not using Papirus Icons.
# One of the functions will load a Photoshop `.webp` icon and convert it to `.png`. The `.png` file will be used in the `.desktop` entry.
check_deps() {
	declare -A packages=(
		["curl"]="curl"
		["wine"]="wine"
		["winetricks"]="winetricks"
		["magick"]="imagemagick"
	)

	missed_packages=()

	for bin in "${!packages[@]}"; do
		if ! command -v "$bin" >/dev/null; then
			missed_packages+=("${packages[$bin]}")
		fi
	done

	if [ ${#missed_packages[@]} -eq 0 ]; then
		echo -e "$CHECK All dependencies are installed."
	else
		echo -e "$WARNING Missing dependencies: ${YELLOW}${missed_packages[*]}${RESET}."
		return 1
	fi
}

install_deps() {
	local can_use_sudo
	can_use_sudo=$(ask_user "Script will use ${RED}sudo${RESET}, do you want to continue?")

	if [[ "${can_use_sudo}" != 0 ]]; then
		print_log "Exiting"
		exit 0
	fi

	case "$OS_ID" in
	"arch")
		# To display the list of packages correctly, we need to format the string.
		# Otherwise `read` will not display the whole list of packages and will stop in the middle of the line.
		missing_packages_str=$(printf "%s " "${missed_packages[@]}")
		# Here we can do without it, but in that case there will be an annoying space before the period at the end of the package listing.
		missing_packages_str=${missing_packages_str% }

		echo -e "$LOG Installing missing dependencies"
		if ! sudo pacman -S "${missed_packages[@]}"; then
			print_error "Pacman terminated with an error."
			exit 1
		fi

		;;
	*)
		echo -e "$ERROR For now only ${BLUE}Arch Linux${RESET} is supported."
		exit 1
		;;
	esac
	echo -e "$LOG Missing dependencies was installed"
}

#							MAIN SCRIPT
# ###################################################################
#

is_path_exists() {
	if [ -d "$1" ]; then
		# BUG
		# echo -e "$WARNING The specified path '$1' already exists."
		echo -e "$WARNING The specified path already exists."

		while true; do
			read -p "$(echo -e "$YELLOW")[WARNING]$(echo -e "$RESET") Do you want to $(echo -e "$RED")delete$(echo -e "$RESET") previous installation? (yes/no): " answer

			case "$answer" in
			[Yy]es | y)
				if rm -rf "${1:?}"; then
					echo -e "$LOG Deleted old installation."
					break
				else
					echo -e "$ERROR Something went wrong."
					exit 1
				fi
				;;
			[Nn]o | n)
				echo -e "$LOG Exiting."
				exit 1
				;;
			*)
				echo -e "$WARNING Invalid input!"
				;;
			esac
		done
	fi
}

setup_wine() {
	export WINEPREFIX="$INSTALL_PATH"
	local vc_libraries=("vcrun2003" "vcrun2005" "vcrun2010" "vcrun2012" "vcrun2013" "vcrun2022")

	echo -e "$LOG Setting up wine prefix."
	winecfg /v win10 2>/dev/null

	# echo -e "${LOG_NORMAL}[LOG]${LOG_RESET} Executing winetricks. All winetricks logs are saved in ${LOG_WARNING}./winetricks.log${LOG_RESET}."
	echo -e "$LOG Executing winetricks."
	echo -e "$LOG Downloading and installing core components for wine prefix. This could take some time."

	if ! winetricks --unattended corefonts win10 vkd3d dxvk2030 msxml3 msxml6 gdiplus &>./install_log.log; then
		echo -e "$ERORR Winetricks terminated with an error."
		echo -e "$ERROR Please open an issue by mentioning the contents of ${YELLOW}./install_log.log${RESET}."
		exit 1
	fi
	{
		echo "---------------------------------------------------------------------"
		echo "                  Downloading Visual C++ Libraries"
		echo "---------------------------------------------------------------------"
	} >>./install_log.log

	echo -e "$LOG Downloading and installing Visual C++ libraries."
	if ! winetricks --unattended "${vc_libraries[@]}" &>>./install_log.log; then
		echo -e "$ERROR Winetricks terminated with an error. Please, refer to ${YELLOW}install_log.log${RESET} for more info."
		# echo -e "${LOG_ERROR}[ERROR]${LOG_RESET} Please open an issue by mentioning the contents of ${LOG_WARNING}./install_log.log${LOG_RESET}."
		echo -e "$ERROR If you can't solve the issue yourself, please, open an issue on the GitHub."
		exit 1
	fi
}

download_photoshop() {
	local archive_name="Photoshop.tar.xz"

	if [ -f "$archive_name" ]; then
		echo -e "$LOG Found existing archive."
		echo -e "$LOG Comparing checksums."
		# TODO:
		# separate function to avoid repeating this task
		local local_checksum
		local_checksum="$(sha256sum "$archive_name" | awk '{print  $1}')"

		if [[ "$CHECKSUM" != "$local_checksum" ]]; then
			echo -e "$LOG Checksums don't match!"
			echo -e "$LOG Deleting corrupted archive."
			rm -v "${archive_name:?}" &>>./install_log.log
		fi

		return 0
	fi
	# echo -e "${LOG_NORMAL}[LOG]${LOG_RESET} Downloading Photoshop (1.1G). Using ${LOG_WARNING}curl${LOG_RESET} as backend. Logs are available in ${LOG_WARNING}./curl.log${LOG_RESET}."
	echo -e "$LOG Downloading Photoshop (1.1G)."
	if ! curl "$PHOTOSHOP_URL" -o "$archive_name" &>>./install_log.log; then
		# TODO:
		# separate function to avoid repeating
		echo -e "$ERROR An error occurred during the download. Please, refer to ${YELLOW}install_log.log${RESET} for more info."
		echo -e "$ERROR If you can't solve the issue yourself, please, open an issue on the GitHub."
		exit 1
	fi

	echo -e "$LOG Photoshop Downloaded."

	# TODO:
	# A separate function so you don't have to write this code multiple times
	echo -e "$LOG Comparing checksums."
	local local_checksum
	local_checksum="$(sha256sum "$archive_name" | awk '{print  $1}')"

	if [[ "$CHECKSUM" != "$local_checksum" ]]; then
		echo -e "$ERROR Checksums don't match!"
		exit 1

	# TODO
	# 	while true; do
	# 		read -p "$(echo -e "$LOG_WARNING")[WARNING]$(echo -e "$LOG_RESET") Do you want to redownload it again? (yes/no): " answer
	# 		case "$answer" in
	# 			pattern)
	# 				command ...
	# 				;;
	# 			*)
	# 				command ...
	# 				;;
	# 		esac
	# 	done
	fi
}

verify_path() {
	local path="$1"

	# Check the validity of the path if the user has specified the absolute path manually. This is necessary in case the user accidentally misspells $HOME paths.
	# https://github.com/shvedes/photoshop-linux/issues/1
	if [[ ! "$path" =~ $HOME ]]; then
		echo -e "$ERROR Cannot validade ${YELLOW}\$HOME${RESET} path."
		exit 1
	fi

	# Fix trailing slashes if needed
	path="$(echo "$path" | sed 's/\/\+$//')"
	INSTALL_PATH="$path"

	# Remove the last folder from the given path (as it will be created by wineprefix) and check the remaining path for validity.
	local reformatted_path="$(echo "$path" | sed 's/\/[^\/]*$//')"

	if [ -d "$reformatted_path" ]; then
		if [[ "$reformatted_path" == "$HOME" ]]; then
			return 0
		else
			echo -e "$CHECK Directory $reformatted_path exist."
		fi
	else
		echo -e "$ERORR Path $reformatted_path does not exist!"
		exit 1
	fi
}

# TODO:
# Do not use the same checks multiple times
install_photoshop() {
	if [ -z "$LOCAL_ARCHIVE" ]; then
		# echo -e "${LOG_NORMAL}[LOG]${LOG_RESET} Installing Photoshop."
		local filename="Photoshop.tar.xz"

		echo -e "$LOG Extracting Photoshop."
		if ! tar xvf "$filename" &>>./install_log.log; then
			echo -e "$ERORR An error occurred while unpacking the archive."
			exit 1
			# TODO:
			# A separate function so you don't have to write this code multiple times
			# while true; do
			# 	read -p "Delete wine prefix?"
			# 	command ...
			# done
		fi

		echo -e "$LOG Installing Photoshop."
		if ! mv "./Adobe Photoshop 2021" "$INSTALL_PATH/drive_c/Program Files"; then
			echo -e "$ERROR An error occurred during installation."
			exit 1
		fi
	else
		echo -e "$LOG Using local Photoshop archive."

		if [[ ! "$LOCAL_ARCHIVE" = *.tar.xz ]]; then
			echo -e "$ERORR Only tar.xz is accepted for now."
			exit 1
			# TODO:
			# Allow user to use not only tar.xz / archive from another sources
		fi

		# TODO:
		# A separate function so you don't have to write this code multiple times
		echo -e "$LOG Comparing checksums."

		local local_checksum="$(sha256sum "$LOCAL_ARCHIVE" | awk '{print  $1}')"

		# TODO:
		# Allow user to skip checksum comparing
		if [[ "$CHECKSUM" != "$local_checksum" ]]; then
			echo -e "$ERROR Checksums don't match!"
			exit 1
		fi

		echo -e "$LOG Extracting Photoshop."
		if ! tar xvf "$LOCAL_ARCHIVE" &>>./install_log.log; then
			echo -e "$ERROR An error occurred while unpacking the archive."
			exit 1
			# TODO:
			# A separate function so you don't have to write this code multiple times
			# while true; do
			# 	read -p "Delete wine prefix?"
			# 	command ...
			# done
		fi

		echo -e "$LOG Installing Photoshop."
		if ! mv "./Adobe Photoshop 2021" "$INSTALL_PATH/drive_c/Program Files"; then
			echo -e "$ERROR An error occurred during installation. Please, refer to ${YELLOW}install_log.log${RESET} for more info."
			echo -e "$ERROR If you can't solve the issue yourself, please, open an issue on the GitHub."
			exit 1
		fi
	fi
}

install_icon() {
	# Papirus Icon Theme already has a Photoshop icon in it.
	# The script will check if you have Papirus installed and use its icon. If Papirus is not installed, the script will download the icon from the Internet and use it.
	if find /usr/share/icons -name "Papirus*" &>/dev/null; then
		ICON="photoshop"
	else
		if [ -d "$XDG_DATA_HOME/icons" ]; then
			if find "$XDG_DATA_HOME/icons" -name "Papirus*" &>/dev/null; then
				ICON="photoshop"
			fi
		else
			mkdir "$XDG_DATA_HOME/icons"
		fi
	fi

	if [ -z "$ICON" ]; then
		local icon_url="https://cdn3d.iconscout.com/3d/premium/thumb/adobe-photoshop-file-3d-icon-download-in-png-blend-fbx-gltf-formats--logo-format-graphic-design-pack-development-icons-9831950.png"
		if ! curl "$icon_url" -o "icon.webp" &>>./install_log.log; then
			echo -e "$ERROR Failed to download icon. Please refer ${YELLOW}install_log.log${RESET} for info."
			exit 1
		fi

		magick "icon.webp" "icon.png"
		rm "./icon.webp"

		echo -e "$LOG Installing icon for .desktop entry."
		mv "./icon.png" "$XDG_DATA_HOME/icons/photoshop.png"
		ICON="$XDG_DATA_HOME/icons/photoshop.png"
	fi
	echo "Icon=${ICON}" >>./photoshop.desktop
}

install_desktop_entry() {
	mkdir "$XDG_DATA_HOME/applications" -p

	local path="$XDG_DATA_HOME/applications/photoshop.desktop"

	echo -e "$LOG Genarating application menu item"

	cp ./photoshop.desktop "${path}"
}

install_launcher() {

	if [ ! -d "$HOME/.local/bin" ]; then
		mkdir "$HOME/.local/bin"
	fi

	echo -e "$LOG Installing launcher."
	{
		echo "#!/usr/bin/env bash"
		echo " "
		echo "WINEPREFIX=\"$WINEPREFIX\""
		echo "DXVK_LOG_PATH=\"\$WINEPREFIX/dxvk_cache\""
		echo "DXVK_STATE_CACHE_PATH=\"\$WINEPREFIX/dxvk_cache\""
		echo "PHOTOSHOP=\"\$WINEPREFIX/drive_c/Program Files/Adobe Photoshop 2021/photoshop.exe\""
		echo " "
		echo "wine64 \"\$PHOTOSHOP\" \"\$@\" "
	} >"${LAUNCHER}"
	chmod +x "$LAUNCHER"
}

main() {
	if ! check_deps; then
		install_deps
	fi

	verify_path "$INSTALL_PATH"
	is_path_exists "$INSTALL_PATH"
	setup_wine

	if [ -z "$LOCAL_ARCHIVE" ]; then
		download_photoshop
		install_photoshop
	else
		install_photoshop
	fi

	install_icon
	install_desktop_entry
	install_launcher

	echo -e "$SUCCES Photoshop is successfully installed."
}

if [[ $# -eq 0 ]]; then
	get_help
	exit 0
fi

while getopts "a:i:h" flag; do
	case $flag in
	a)
		LOCAL_ARCHIVE="$OPTARG"
		;;
	h)
		get_help
		;;
	i)
		INSTALL_PATH="$OPTARG"
		;;
	\?)
		echo "Invalid option: -$OPTARG Use -h for help."
		exit 1
		;;
	esac
done

main
