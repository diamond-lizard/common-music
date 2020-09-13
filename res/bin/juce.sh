#!/bin/bash

cd `dirname $0`
cd ../..

if [ ! -f "premake4.lua" ] ; then
  echo "juce.sh is not running from the correct directory."
  echo "Try running this script from the top-level cm directory."
  exit 1
fi

USAGE="
    Usage: res/bin/juce.sh 

    Installs the JUCE tip into using 'git'
"

# print help and exit
if [[ "$1" == "--help" ]] ; then
    echo "$USAGE"
    exit 1
fi

TOP=`pwd`

if [ -d "juce/modules" ] ; then
    exit 0
fi

if ! which git >/dev/null; then
    echo "*** Error: Cannot find git on your path."
    echo "Install juce sources in ${TOP}/juce and try premake4 again."
    exit 1
fi

echo ==== Downloading JUCE into ${TOP}/juce ====

git clone --depth 1 git://juce.git.sourceforge.net/gitroot/juce/juce/ juce

exit 0

