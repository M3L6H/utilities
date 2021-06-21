#!/bin/bash

app="$(cat .app)"
base_dir="$(dirname "$0")"
dist="${base_dir}/dist"

mkdir "$dist" >/dev/null 2>&1
rm "$dist"/*.tar.gz 2>/dev/null
tar -cvf "${dist}/${app}-$(<"${base_dir}/data/version").tar.gz" \
  data/ \
  scripts/ \
  .app \
  install.sh \
  reinstall.sh \
  uninstall.sh \
  README.md \
  CHANGELOG.md
