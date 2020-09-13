#!/bin/bash

cd `dirname $0`

cd ../..
HERE=`pwd`
CMDIR=`basename $HERE`

if [ ! -f "premake4.lua" ] ; then
  echo "buildinfo.sh is not running from the correct directory."
  echo "Try calling this script from the top-level cm directory."
  exit 1
fi

plist="res/app/Info.plist"
svn update
rev=$(svn info | grep '^Revision:' | sed -e 's/^Revision: //')
rev=$(($rev + 1))
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $rev" "$plist"

