#!/bin/bash
set -xe

echo ANDROID_HOME is $ANDROID_HOME

echo PATH is $PATH

export PATH="/usr/local/bin:/usr/local/Cellar/cmake/3.16.3/bin:/Users/runner/Library/Android/sdk/cmake/3.6.4111459/bin:/Applications/Android Studio.app/Contents/jre/jdk/Contents/Home/bin":~/Library/Android/sdk/platform-tools:$PATH 
export ANDROID_HOME=${ANDROID_HOME:-~/Library/Android/sdk}
export VISORSRC="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export APPSRC=$VISORSRC/deps/lovr-android
export GRADLE=$APPSRC/gradlew
export CMAKEVER=$(cmake --version | head -n 1 | cut -d " " -f 3)

sed -i "s/3.16.3/$CMAKEVER/g" deps/lovr-android/cmakelib/build.gradle

pushd $APPSRC

pushd cmakelib
$GRADLE $1
popd

pushd LovrApp/Projects/Android
$GRADLE $1
popd

popd


