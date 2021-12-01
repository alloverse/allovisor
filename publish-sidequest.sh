#!/bin/bash
set -ex

VERSION="$BUILD_BUILDID"
TOKEN="$SIDEQUEST_TOKEN"
FILENAME=`find build -maxdepth 1 -iname "Alloverse*.apk" | sed s/build/visor/`
LONG_VERSION=`cat build/include/allovisor_version.txt`
URL="https://alloverse-downloads-prod.s3.amazonaws.com/$FILENAME"


curl -v -X POST \
    https://sdq.st/version-webhook/$VERSION/$SIDEQUEST_TOKEN \
    -H 'Accept: */*' \
    -H 'Accept-Encoding: gzip, deflate' \
    -H 'Cache-Control: no-cache' \
    -H 'Connection: keep-alive' \
    -H 'Content-Type: application/json' \
    -H 'Host: sdq.st' \
    -H 'cache-control: no-cache' \
    -d '{
    "url": "$URL"
    }'
