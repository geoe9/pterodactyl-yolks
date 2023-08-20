#!/bin/bash

#
# Copyright (c) 2021 Matthew Penner
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# Give everything time to initialize for preventing SteamCMD deadlock
sleep 1

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

# Convert all of the "{{VARIABLE}}" parts of the command into the expected shell
# variable format of "${VARIABLE}" before evaluating the string and automatically
# replacing the values.
PARSED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")

## just in case someone removed the defaults.
if [ "${STEAM_USER}" == "" ]; then
    echo -e "steam user is not set.\n"
    echo -e "Using anonymous user.\n"
    STEAM_USER=anonymous
    STEAM_PASS=""
    STEAM_AUTH=""
else
    echo -e "user set to ${STEAM_USER}"
fi

## if auto_update is not set or to 1 update
if [ -z ${AUTO_UPDATE} ] || [ "${AUTO_UPDATE}" == "1" ]; then
    # Update Source Server
    if [ ! -z ${SRCDS_APPID} ]; then
        ./steamcmd/steamcmd.sh +force_install_dir /home/container +login ${STEAM_USER} ${STEAM_PASS} ${STEAM_AUTH} +app_update ${SRCDS_APPID} $( [[ -z ${SRCDS_BETAID} ]] || printf %s "-beta ${SRCDS_BETAID}" ) $( [[ -z ${SRCDS_BETAPASS} ]] || printf %s "-betapassword ${SRCDS_BETAPASS}" ) $( [[ -z ${HLDS_GAME} ]] || printf %s "+app_set_config 90 mod ${HLDS_GAME}" ) $( [[ -z ${VALIDATE} ]] || printf %s "validate" ) +quit
    else
        echo -e "No appid set. Starting Server"
    fi

else
    echo -e "Not updating game server as auto update was set to 0. Starting Server"
fi

if [ ! -d "~/.ssh" ]; then
    mkdir ~/.ssh
fi

if [ ! -e "~/.ssh/id" ]; then
    touch "~/.ssh/id"
    chmod 600 ~/.ssh/id
fi

if [ ! -s "~/.ssh/id" ]; then
    echo -e "Please update ~/.ssh/id with your (private) GitHub deploy key."
    exit 1
fi

if [ ! -e "~/.ssh/id.pub" ]; then
    ssh-keygen -f ~/.ssh/id -y > ~/.ssh/id.pub
fi

ssh-keyscan -p 22 github.com >> ~/.ssh/known_hosts

if [ ! -d "~/.git" ]; then
    git init
    git config --local user.name "geor.dev"
    git config --local user.email "noreply@geor.dev"

    # Prepare to push initial commit
    echo '# Root directory - ignore everything but garrysmod directory and repo files
    /*
    !/garrysmod
    !/.gitignore
    !/README.md
    !/CONTRIBUTING.md


    # garrysmod directory - Only allow repo files
    /garrysmod/*
    !/garrysmod/addons
    !/garrysmod/cfg
    !/garrysmod/gamemodes
    !/garrysmod/html
    !/garrysmod/lua
    !/garrysmod/resources
    !/garrysmod/scripts
    !/garrysmod/settings
    !/garrysmod/detail.vbsp
    !/garrysmod/gameinfo.txt
    !/garrysmod/lights.rad

    # Prevent secrets from being accidentally leaked by not allowing cfg folder to be updated normally
    /garrysmod/cfg/*

    # Do not add spawnlists
    /garrysmod/settings/spawnlist/*' > .gitignore

    git add .
    git commit -m "Initial commit"
    git branch -M main
    git remote add origin git@github.com:{$GITHUB_USER}/{$GITHUB_REPO}.git
    git push -u origin main
fi

if [ -d "~/.git" ]; then
    git pull
fi

# Display the command we're running in the output, and then execute it with the env
# from the container itself.
printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n" "$PARSED"
# shellcheck disable=SC2086
exec env ${PARSED}
