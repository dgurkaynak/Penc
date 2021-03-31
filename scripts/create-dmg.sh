#!/usr/bin/env bash
set -e

# Check whether create-dmg exists
if ! command -v create-dmg &> /dev/null
then
    echo "create-dmg command not found"
    echo "https://github.com/create-dmg/create-dmg"
    exit 1
fi

# If there is no first argument (source), give error
if [ -z "$1" ]
then
    echo "Missing arguments"
    echo ""
    echo "Usage:"
    echo "./scripts/create-dmg.sh ./source/folder ./output.dmg"
    echo ""
    echo "Notes:"
    echo "- Source folder must contain just 'Penc.app' file"
    exit 1
fi

# If there is no second argument (target), give error
if [ -z "$2" ]
then
    echo "Missing arguments"
    echo ""
    echo "Usage:"
    echo "./scripts/create-dmg.sh ./source/folder ./output.dmg"
    echo ""
    echo "Notes:"
    echo "- Source folder must contain just 'Penc.app' file"
    exit 1
fi

create-dmg \
    --volname "Penc" \
    --background "./scripts/dmg-assets/installer-bg.jpg" \
    --window-size 600 400 \
    --icon-size 80 \
    --icon "Penc.app" 150 235 \
    --hide-extension "Penc.app" \
    --app-drop-link 450 235 \
    "$2" \
    "$1"

