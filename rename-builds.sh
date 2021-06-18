#!/bin/sh
set -e

VERSION=`cat build/include/allovisor_version.txt | xargs echo -n`
INSTALLERFILE=`find build -name "*0.2.0*.exe" -or -name "*0.2.0*.dmg" -or -name "*0.2.0*.apk"`

if [ -z "$INSTALLERFILE" ];
then
    echo "no build found to rename"
    exit 1
fi

NEWNAME=`echo $INSTALLERFILE | sed s/0\.2\.0/$VERSION/ | sed s/Darwin/mac/`
echo "Renaming $INSTALLERFILE to $NEWNAME"
mv $INSTALLERFILE $NEWNAME