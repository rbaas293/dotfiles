#!/bin/bash

#if [[ $EUID -ne 0 ]]; then
#   echo "This script must be run as root"
#   exit 1
#fi

# Added `microsoft` due to `uname -v` returning `#836-Microsoft Mon May 05 16:04:00 PST 2020` on a WSL version.
version=$(uname -v)
debbased=$(echo $version | grep -Pio "(debian|ubuntu|microsoft)")
if [[ "$debbased" = "Debian" ]] || [[ "$debbased" = "Microsoft" ]] || [[ "$debbased" = "Ubuntu" ]]
then
	#echo Running on a Debian Based Distro.
	#apt update
	#apt install zsh -y
	echo "Run the Following:"
	echo "apt update"
	echo "apt install zsh -y"
	exit 1
exit 0
else
	#echo Using Pacman.
	pacman -S zsh
fi
