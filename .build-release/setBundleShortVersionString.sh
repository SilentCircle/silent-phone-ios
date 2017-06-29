#!/bin/bash
#
# Apple requires that the app and its extension have the same CFBundleShortVersionString

if (( $# != 1 )); then
   echo "Only one argument, the BundleShortVersionString."
   exit
fi

VERSION_STRING="$1"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION_STRING" ./spi3/Info.plist

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION_STRING" ./IntentHandler/Info.plist


