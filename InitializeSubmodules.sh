#!/bin/bash
if [ -d "../.git" ]; then
REPOS_INCLUDING_SUBMODULES=`find .. -name ".gitmodules"`
SCRIPT_PATH=`pwd`
for FILEPATH in $REPOS_INCLUDING_SUBMODULES
do
echo Updating submodules at "$SCRIPT_PATH"/"$FILEPATH"
DIRECTORY=`echo "$FILEPATH" | sed 's|\(.*\)/.*|\1|'`
cd $DIRECTORY
git submodule init
git submodule update	
cd - > /dev/null
done
else
echo "Please execute this script in his original location"
fi
