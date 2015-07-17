#!/bin/bash

# YYYY.MM.DD
TODAY=$(date +%Y.%m.%d)

# count commits occuring today..
COUNT=$(git tag -l "$TODAY.*" | wc -l)
MINOR=$(($COUNT+1))

GIT_HASH=$(git rev-parse --short HEAD)

VERSION="$TODAY.xtuni.$MINOR.$GIT_HASH"
# example output:
# xt_uni-2015-06-12-02.183c90c
#
# meaning: (xt unicorn, 2nd release 12th June 2015, commit hash)

echo -n $VERSION > "VERSION"
