#!/bin/bash

rm -drf dist
mkdir dist 2>/dev/null

for dir in $(find . -maxdepth 1 -mindepth 1 -type d -printf '%f\n'); do
  [ "$dir" = 'dist' ] && continue
  [ "$dir" = '.git' ] && continue
  tar -czvf "dist/${dir}-$(<"${dir}/data/version").tar.gz ${dir}/"
done
