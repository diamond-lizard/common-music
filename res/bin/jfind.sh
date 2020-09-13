#!/bin/bash

#Guarantee that the current directory is the top level directory
cd `dirname $0`
cd ../..
if [ ! -f "premake4.lua" ] ; then
  echo "Run script from the top-level CM directory."
  exit 1
fi

USAGE="
    Usage: res/bin/jfind.sh [pattern]

    Recursively greps for pattern in all .h and .cpp files under juce/modules
"

# if no args print help and exit
if [[ "$#" == 0 ]] ; then
    echo "$USAGE"
    exit 1
fi

find juce/modules \( -name "*.h" -o -name "*.cpp" \) | xargs grep "$*" - 



