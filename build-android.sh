#!/bin/bash
set -xe

export PATH="/Applications/Android Studio.app/Contents/jre/jdk/Contents/Home/bin":~/Library/Android/sdk/platform-tools:$PATH 
export ANDROID_HOME=~/Library/Android/sdk 
export VISORSRC="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export APPSRC=$VISORSRC/deps/lovr-android
export GRADLE=$APPSRC/gradlew

pushd $APPSRC

pushd cmakelib
$GRADLE build
popd

pushd LovrApp/Projects/Android
$GRADLE build
popd

popd


