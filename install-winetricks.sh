#!/bin/bash

clone_dir=$1
mkdir -p "${clone_dir}"
cd "${clone_dir}" || exit 1
if ! [ -f ./Makefile ] ; then 
  git clone https://github.com/Winetricks/winetricks "${clone_dir}"
fi
sudo make install
