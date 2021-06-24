#!/bin/bash

FILENAME=`find build -maxdepth 1 -iname "Alloverse*.exe" -or -iname "Alloverse*.dmg" -or -iname "Alloverse*.apk" | sed s/build/visor/`
PLATFORM=$1
VERSION=`cat build/include/allovisor_version.txt`
URL="https://alloverse-downloads-prod.s3.amazonaws.com/$FILENAME"

generate_post_data()
{
  cat <<EOF
{
  "PublishingSecret": "${PUBLISHING_SECRET}",
  "platform": "${PLATFORM}",
  "version": "${VERSION}",
  "url": "${URL}"
}
EOF
}

curl \
    -H "Content-Type:application/json"\
    -X POST\
    --data "$(generate_post_data)"\
    https://alloverse.com/hooks/pipelines_json.php
