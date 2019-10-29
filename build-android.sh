#!/bin/bash
set -xe

echo ANDROID_HOME is $ANDROID_HOME

export PATH="/Applications/Android Studio.app/Contents/jre/jdk/Contents/Home/bin":~/Library/Android/sdk/platform-tools:$PATH 
export ANDROID_HOME=${ANDROID_HOME:-~/Library/Android/sdk}
export VISORSRC="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export APPSRC=$VISORSRC/deps/lovr-android
export GRADLE=$APPSRC/gradlew

pushd $APPSRC

pushd cmakelib
$GRADLE $1
popd

pushd LovrApp/Projects/Android
$GRADLE $1
popd

popd


