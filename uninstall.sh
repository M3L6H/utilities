#!/bin.bash

NF="\e[0m"
BOLD="\e[1m"
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"

app="$(cat "$(dirname "$0")/.app")"

printf "${RED}${BOLD}Are you sure you want to uninstall '${app}'? (y/N)${NF}"
read -sr -n 1 ans
echo
case "$ans" in
  y|Y) ;;
  *)
    echo "Uninstallation cancelled"
    exit 0
  ;;
esac

echo "Checking for '${app}'..."

if which $app >/dev/null 2>&1; then
  printf "${GREEN}'${app}' found${NF}\n"

  bin="$(dirname $(which "$app"))"

  echo "Removing '${app}'..."
  rm "$(which $app)"
  printf "${GREEN}'${app}' removed${NF}\n"

  echo "Removing '${app}' data..."
  rm -drf "${HOME}/.${app}"
  printf "${GREEN}'${app}' data removed${NF}\n"

  echo "Removing '${bin}..."
  if ! [ -n "$(ls -A "$bin" 2>/dev/null)" ]; then
    rm -d "$bin"
    printf "${GREEN}'${bin}' removed${NF}\n"
    printf "${BLUE}NOTE: You will need to manually edit your bash config file to remove '${bin}' from the PATH\n"
  else
    printf "${YELLOW}'${bin}' not empty, skipping this step${NF}\n"
  fi
else
  printf "${RED}Could not find an installation of '${app}' on this system!${NF}\n"
  exit 1
fi

printf "${GREEN}${app} uninstalled${NF}\n"
