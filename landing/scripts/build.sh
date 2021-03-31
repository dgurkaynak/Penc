#!/usr/bin/env bash
set -e

if [ -z "$PENC_DOWNLOAD_VERSION" ]
then
    echo "You must pass a valid PENC_DOWNLOAD_VERSION env variable!" 1>&2
    exit 1
fi

rm -rf dist
./node_modules/.bin/parcel build index.html --public-url ./ --out-dir dist
./node_modules/.bin/inline-assets dist/index.html dist/index.html
