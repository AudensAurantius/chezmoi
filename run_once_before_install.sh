#!/bin/sh

# install essential tools
sudo apt-get install -y curl git pass gpg

# install mise
curl https://mise.run | sh

# install pyenv
curl https://pyenv.run | bash

# get password store
git clone https://github.com/antimike/pass ~/.password-store

# modify WSL-related /etc/ files
printf '%s\n' '[boot]' 'systemd=true' | sudo tee /etc/wsl.conf
