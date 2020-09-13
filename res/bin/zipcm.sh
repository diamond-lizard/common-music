#!/bin/bash

cd `dirname $0`

cd ../..
HERE=`pwd`
CMDIR=`basename $HERE`

if [ ! -f "premake4.lua" ] ; then
  echo "zipcm.sh is not running from the correct directory."
  echo "Try calling this script from the top-level cm directory."
  exit 1
fi

ZIPFILE=

case "$1" in
    *.zip)
        ZIPFILE=$1
        ;;
    *)
        echo "Usage: zipcm.sh {zipfile}"
        exit 1
        ;;
esac

if [ -f "../$ZIPFILE" ] ; then
  echo ">>> Error: a file named $ZIPFILE already exists in the parent directory."
  exit 1
fi

#echo "sourcedir = $CMDIR, archive = $ZIPFILE"

# move to cm's parent directory

cd ..

# zip cm sources into specified zip file

zip -9 -r "$ZIPFILE" "$CMDIR" -x "*.DS_Store" -x "*.svn*" -x "*.git*" -x "$CMDIR/lib/*" -x "$CMDIR/obj/*" -x "$CMDIR/bin/*" "$CMDIR/sndlib/lib/*" -x "$CMDIR/sndlib/obj/*" -x "$CMDIR/sndlib/bin/*" -x "*Makefile" -x "*.make"  -x "*/juce/extras/*"


