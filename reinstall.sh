#!/bin/bash

NF="\e[0m"
BOLD="\e[1m"
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"

app="$(cat "$(dirname "$0")/.app")"
skip_prompts=false

while getopts ":y" opt; do
  case "$opt" in
  y) skip_prompts=true ;;
  *)
    echo "Unrecognized argument"
    exit 1
  ;;
  esac
done

printf "${BLUE}'$app' will be reinstalled (y/N)${NF}"
"$skip_prompts" && ans='y' || read -sr -n 1 ans
echo
case "$ans" in
  y|Y) ;;
  *)
    echo "Reinstallation cancelled"
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

  echo "Reinstalling '${app}'..."
  cp "$(dirname "$0")/scripts/${app}.sh" "${bin}/${app}"
  chmod u+x "${bin}/${app}"
  data="${HOME}/.${app}/"
  cp -r "$(dirname "$0")"/data/* "$data"
  cp "$(dirname "$0")"/*.md "$data"
  cp "$(dirname "$0")/.app" "$data"
  cp "$(dirname "$0")/uninstall.sh" "$data"
  printf "${GREEN}'${app}' reinstalled${NF}\n"
else
  printf "${RED}Could not find an installation of '${app}' on this system!${NF}\n"
  exit 1
fi

printf "${GREEN}${app} successfully reinstalled${NF}\n"
printf "${GREEN}Run it using '${app}' or create an alias for it in your shell config file${NF}\n"
printf "${BLUE}You may need to restart your terminal or run 'source <shell config file>' first${NF}\n"
