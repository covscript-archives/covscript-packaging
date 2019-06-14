#!/usr/bin/env bash

if [[ "$#" != 1 ]];then
    echo "Usage: $(basename $0) <app>"
    exit 1
fi


mkdir .$$.install

(cd .$$.install && ln -s /Application .)
cp -r "$1" .$$.install/

hdiutil create -volname CovScript -srcfolder $PWD/.$$.install -ov -format UDZO covscript.dmg

rm -rf .$$.install

