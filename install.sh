#!/bin/bash

NF="\e[0m"
BOLD="\e[1m"
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"

bin="$HOME/.local/bin"
app="$(cat $(dirname "$0")/.app)"

printf "Welcome to the ${BOLD}${app}${NF} installer\n"
printf "This installer will guide you through the process of installing ${BOLD}${app}${NF} on your system\n"
printf "${BLUE}Press any key to continue${NF}\n"
read -sr -n 1

echo "Checking for '${app}'..."

which "$app" > /dev/null 2>&1

if [ "$?" -eq '0' ]; then
  echo "${YELLOW}'${app}' found. Uninstall by running the uninstall script.${NF}"
  exit 1
fi

echo "'${app}' not found. Installing '${app}'..."

while true; do
  printf "${BLUE}Enter the path where you would like to install '${app}' (default: '${bin}'): ${NF}"
  read tmp

  [ -n "$tmp" ] && bin="$tmp"
  printf "${BLUE}'${app}' will be added to '${bin}' (y/N)${NF}"
  read -sr -n 1 ans
  echo
  case "$ans" in
    y|Y) break ;;
  esac
done

echo

mkdir -p "$bin" >/dev/null 2>&1

shell_config=''
configured='0'
shell_configs=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile")

for shell_config in "${shell_configs[@]}"; do
  if [ -f "$shell_config" ]; then
    if ! grep -q "$bin" <<< "$PATH"; then
      echo "export PATH=$bin:\$PATH" >> "$shell_config"
    fi
    configured='1'
    break
  fi
done

cp "$(dirname "$0")/scripts/${app}.sh" "$bin/$app"
mkdir "${HOME}/.${app}"
cp -a "$(dirname "$0")/data/." "${HOME}/.${app}/"
cp $(dirname "$0")/*.md "${HOME}/.${app}/"
chmod u+x "${bin}/${app}"

printf "${GREEN}${app} successfully installed.${NF}\n"
printf "${GREEN}Run it using '${app}' or create an alias for it in your shell config file.${NF}\n"

if [ "$configured" -ne '0' ]; then
  printf "${BLUE}You may need to restart your terminal or run 'source ${shell_config}' first${NF}\n"
else
  printf "${YELLOW}Could not find a recognized shell config file${NF}\n"
  printf "${YELLOW}If you already have one, then please add \"export PATH=${bin}:\$PATH\" to it${NF}\n"
  printf "${YELLOW}If not, you will need to create on and add the above line to it${NF}\n"
  printf "${BLUE}After reading the above note, press any key to continue${NF}\n"
  read -sr -n 1
fi
