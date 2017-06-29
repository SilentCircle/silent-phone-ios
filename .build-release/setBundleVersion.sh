#!/bin/bash
#
# Apple requires that the app and its extensions have the same CFBundleVersion

if (( $# != 1 )); then
   echo "Only one argument, the BundleVersion."
   exit
fi

BUNDLE_VERSION="$1"

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUNDLE_VERSION" ./spi3/Info.plist

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUNDLE_VERSION" ./IntentHandler/Info.plist


