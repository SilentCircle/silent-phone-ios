#!/bin/bash

echo "Git scatters submodule information around the repo, this attempts to clean it out"
echo "  - remove submodule lines from the .git/config file"
echo "  - remove submodule caches from .git/module/libs"
echo "  - remove submodule directories from libs/"
echo
read -p "Do these things? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  cp .git/config .git/config.orig

  sed -i '' '\#submodule "libs/libzina"#d' .git/config
  sed -i '' '\#url = ssh://git@code-ssh.silentcircle.org:7999/SP/axolotlzrtp.git#d' .git/config
  sed -i '' '\#submodule "libs/polarssl"#d' .git/config
  sed -i '' '\#url = ssh://git@code-ssh.silentcircle.org:7999/VEN/polarssl.git#d' .git/config
  sed -i '' '\#submodule "libs/sqlcipher"#d' .git/config
  sed -i '' '\#url = ssh://git@code-ssh.silentcircle.org:7999/ven/sqlcipher.git#d' .git/config
  sed -i '' '\#submodule "libs/tiviengine"#d' .git/config
  sed -i '' '\#url = ssh://git@code-ssh.silentcircle.org:7999/sp/silentphone.git#d' .git/config
  sed -i '' '\#submodule "libs/werner_zrtp"#d' .git/config
  sed -i '' '\#url = ssh://git@code-ssh.silentcircle.org:7999/SP/zrtp-ios-proj.git#d' .git/config
  sed -i '' '\#submodule "libs/zrtp"#d' .git/config
  sed -i '' '\#url = ssh://git@code-ssh.silentcircle.org:7999/VEN/zrtpcpp.git#d' .git/config

  rm -rf .git/modules/libs/libzina
  rm -rf .git/modules/libs/polarssl
  rm -rf .git/modules/libs/sqlcipher
  rm -rf .git/modules/libs/tiviengine
  rm -rf .git/modules/libs/werner_zrtp
  rm -rf .git/modules/libs/zrtp

  rm -rf libs/libzina
  rm -rf libs/polarssl
  rm -rf libs/sqlcipher
  rm -rf libs/tiviengine
  rm -rf libs/werner_zrtp
  rm -rf libs/zrtp
fi