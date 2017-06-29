#!/bin/bash
#
# This is a work in process.  Sorting out what bits need to be in the
# build wrapper.

# build configuration should be Debug or Release
#
export BUILD_CONFIGURATION="$1"; shift

# build variant could be:
#  "devnet"            : produces ipa that run on the development net
#  "releasecandidate"  : to build an ipa suitable for uploading to the Apple store
#  "" : nothing, no variant#
#
export BUILD_VARIANT="$1"; shift


ISO_B8601DZ="%Y%m%dT%H%M%SZ"
DateISO=$(date -j -u "+$ISO_B8601DZ")
DatePretty=$(date -j -u -f "$ISO_B8601DZ" "$DateISO" +%Y-%m-%dT%H:%M:%SZ)

BUILD_ID="$DateISO"

# Workspace is where the git repo is and the job is being built.
#
export WORKSPACE
WORKSPACE=$(pwd)

LocalTools="$HOME/gitlab-local-tools"
jsonBuddy="$WORKSPACE/.build-release/jsonBuddy.py"

BUILD_FLAGS="$BUILD_CONFIGURATION"

# Where it can, it speaks out
#
say() {
 local what="$1"

 local sayTool="${LocalTools}/tell.sh"

 if [ -f "$sayTool" ]; then
     "$sayTool" "$what"
 fi
}


checkStatus() {
 status=$1
 if [ $status -ne 0 ]
 then
     printf "Build failed!"
     say "FAILED FAILED FAILED, build $jobName"
     exit $status
 fi
}


# this used to be set by jenkins
# temporarily force a build number here
export BUILD_NUMBER="$DateISO"

# use the BUILD_NUMBER as the default BUNDLE_VERSION
# it is overwritten later if a releasecandidate
#
export BUNDLE_VERSION="$BUILD_NUMBER"

# clean the workspace short of removing the repo
git rev-parse --verify HEAD
git reset --hard HEAD
git clean -x -d -f --exclude build.log

# TODO: Figure out what branches are being built

jobName="ci test build as $BUILD_CONFIGURATION"
jobMission=$(git log -1 --pretty=format:"%d %an  %ar  %s")
say "$jobName starting build $BUILD_NUMBER, $jobMission"

# presume failure it will be overwritten on success
#
echo "FAILED" > status.txt

# if needed update the provisioning profiles
#
.build-release/updateProfiles.py .build-release "${HOME}/Library/MobileDevice/Provisioning Profiles/"

# unlock the local keychain and the signing ids
#
source "$LocalTools/silent-phone-build-local-config.sh"

printf "\n\n_____ Build Phase 0 Completed _____\n\n"

export BUILD_APP_ARCHS="armv7 arm64"
export BUILD_OPTIONS_VoipPhone="-derivedDataPath $WORKSPACE/DerivedData"

export ADHOC_ENTITLEMENTS_PATH="$WORKSPACE/.build-release/adhoc-entitlements.plist"
export ADHOC_EXPORT_OPTIONS_PATH="$WORKSPACE/.build-release/adhoc-export-options.plist"
export ADHOC_SIGNING_ID=F4790E778890E340D35C8B88FB50EA5E9AEE4F03

export ENTER_ENTITLEMENTS_PATH="$WORKSPACE/.build-release/enterprise-entitlements.plist"
export ENTER_EXPORT_OPTIONS_PATH="$WORKSPACE/.build-release/enterprise-export-options.plist"
export ENTER_SIGNING_ID=7C2192CC4CCD2072C8EA44290DF26BEAF461CC87

export GCC_PREPROCESSOR_DEFINITIONS_VoipPhone="USE_PRODUCTION_APNS"

# A devnet build requires a patch be applied to enable use of the developer network
#
if [[ "$BUILD_VARIANT" == "devnet" ]]; then
   printf "applying devnet patch"

   patch -p1 < .build-release/spi3-use-dev-network-provisoning.patch
   retval=$?
   if [ $retval -ne 0 ]; then
      echo "devnet patch failed, return code: $retval"
      exit $retval
   fi

   BUILD_FLAGS="devnet, $BUILD_FLAGS"
fi


if [[ "$BUILD_VARIANT" == "releasecandidate" ]]; then
   printf "setting up to build a release candidate"

   export STORE_ENTITLEMENTS_PATH="$WORKSPACE/.build-release/store-entitlements.plist"
   export STORE_EXPORT_OPTIONS_PATH="$WORKSPACE/.build-release/store-export-options.plist"
   export STORE_SIGNING_ID=F4790E778890E340D35C8B88FB50EA5E9AEE4F03

   export BUNDLE_VERSION=$($LocalTools/GetBundleVersion.sh)
   BUILD_FLAGS="releasecandidate, $BUILD_FLAGS"
fi


# a script sets the bundle version of both the app and its extensions
# if present use it otherwise fallback to plistbuddy.
#
printf "Set spi3/Info.plist :CFBundleVersion to $BUNDLE_VERSION"
if [ -f ".build-release/setBundleVersion.sh" ]
then
   .build-release/setBundleVersion.sh "$BUNDLE_VERSION"
else
   /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUNDLE_VERSION" ./spi3/Info.plist
fi

.build-release/build.sh
checkStatus $?

printf "\n\n_____ Build Phase 1 Completed _____\n\n"

# get the bundle version information from the xcarchive
BundleVersion="$(plutil -p ./SilentPhone.xcarchive/Info.plist | grep "CFBundleVersion" | awk '{gsub(/"/, "", $3); print $3}')"

# package debugging symbols
#
( cd SilentPhone.xcarchive || return ; zip -r ../dsyms dSYMs )

packageResults() {
  local builtIPA="$1"; shift
  local sourceManifest="$1"; shift
  local resultsDir="$1"; shift
  local resultsIPA="$1"; shift
  local typeIPA="$1"; shift
  local buildFlags="$1"; shift

  if [ ! -f "$builtIPA" ]; then
    return
  fi

  mkdir -p "$resultsDir"
  cp dsyms.zip "$resultsDir"
  mv "$builtIPA" "$resultsDir"
  cp ".build-release/$sourceManifest" "$resultsDir/manifest.plist.orig"

  local buildinfo="$resultsDir/ci_build_info.json"
  $jsonBuddy "$buildinfo" write commit.who      "$(git show -s --pretty=%aN)"
  $jsonBuddy "$buildinfo" write commit.date     "$(git show -s --pretty=%cD)"
  $jsonBuddy "$buildinfo" write commit.id       "$(git show -s --pretty=%H)"
  $jsonBuddy "$buildinfo" write commit.id.short "$(git show -s --pretty=%h)"
  $jsonBuddy "$buildinfo" write commit.subject  "$(git show -s --pretty=%s)"
  $jsonBuddy "$buildinfo" write commit.repo     "https://lab.silentcircle.org/eng/spi"
  $jsonBuddy "$buildinfo" write commit.branches "$(git show -s --pretty=%D)"

  $jsonBuddy "$buildinfo" write ipa.name        "$builtIPA"
  $jsonBuddy "$buildinfo" write ipa.sha1        "$(openssl sha1 $resultsDir/$builtIPA | awk '{print $2}')"
  $jsonBuddy "$buildinfo" write ipa.type        "$typeIPA"
  $jsonBuddy "$buildinfo" write manifest.orig   "manifest.plist.orig"

  $jsonBuddy "$buildinfo" write build.number    "$BUILD_ID"
  $jsonBuddy "$buildinfo" write build.date      "$DatePretty"
  $jsonBuddy "$buildinfo" write build.config    "$BUILD_CONFIGURATION"
  $jsonBuddy "$buildinfo" write build.bundlever "$BundleVersion"
  $jsonBuddy "$buildinfo" write build.flags     "$buildFlags"
}

# if the context is present post results
#
postResults() {
 local resultsDir="$1"

 local postTool="${LocalTools}/ci_spi_post_results.sh"

 if [ -f "$postTool" ]; then
     "$postTool" "$resultsDir"
 fi
}


# package and post the results
#
packageResults SPi3.ipa manifest.plist \
               results-adhoc SilentPhone.ipa adhoc "$BUILD_FLAGS, adhoc"

packageResults EnterprisePhone.ipa manifest-enterprisephone.plist \
               results-ent EnterprisePhone.ipa enterprise "$BUILD_FLAGS, enterprise"

postResults results-adhoc
postResults results-ent


if [[ "$BUILD_VARIANT" == "releasecandidate" ]]; then

   # The package results for uploading to the Apple store
   # - the manifest.plist is bogus because store kits are only downloadable by apple
   #   but the function here requires something...
   #
   packageResults SPi3-store.ipa manifest.plist \
                  results-store spi3-store.ipa store "$BUILD_FLAGS, store"

   postResults results-store
fi

printf "\n\n_____ Build Phase 2 Completed _____\n\n"

echo "SUCCESSFUL" > status.txt

say "SUCCESS, build $jobName"
