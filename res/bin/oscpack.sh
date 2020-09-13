#!/bin/bash

cd `dirname $0`
cd ../..

if [ ! -f "premake4.lua" ] ; then
  echo "oscpack.sh is not called from the correct directory."
  echo "Try running this script from the top-level cm directory."
  exit 1
fi

USAGE="
    Usage: res/bin/oscpack.sh 

    Installs oscpack head revision using 'svn'
"

# print help and exit
if [[ "$1" == "--help" ]] ; then
    echo "$USAGE"
    exit 1
fi

TOP=`pwd`

if [ -d "oscpack" ] ; then
    exit 0
fi

if ! which svn >/dev/null; then
    echo "*** Error: Cannot find svn on your path."
    echo "Install oscpack sources in ${TOP}/oscpack and then 'make' again."
    exit 1
fi

echo ==== Downloading OscPack into ${TOP}/oscpack ====

svn checkout http://oscpack.googlecode.com/svn/trunk/ oscpack

exit 0

