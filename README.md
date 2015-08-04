## Introduction

These are the sources for Silent Circle's Silent Phone for iOS project.

### What's New In This Update

- the sources are updated for version 1.10.1 of the project 

### Overview

Silent Phone is Peer-to-peer encrypted calling and video. No keys are stored.

### Prerequisites

To build Silent Text you need Xcode 6.1 or higher and the Command Line Tools.

### How to Build

- Download the repository
- create a terminal window
- cd to the top of the repository
- bash build-release/SilentPhoneBuild.sh 2>&1 | tee -a xcodebuild.log 

The build produces SilentPhone.xcarchive which contains the app and can be use to make an ipa.
