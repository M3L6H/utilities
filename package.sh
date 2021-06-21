#!/bin/bash

base_dir=$(dirname $0)
dist="${base_dir}/dist"

rm -drf "$dist"
mkdir "$dist" 2>/dev/null

for dir in $(find "$base_dir" -maxdepth 1 -mindepth 1 -type d -printf '%f\n'); do
  [ "$dir" = 'dist' ] && continue
  [ "$dir" = '.git' ] && continue
  tar -czvf "${dist}/${dir}-$(<"${base_dir}/${dir}/data/version").tar.gz" "${base_dir}/${dir}/"
done
