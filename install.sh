#!/bin/bash

NF="\e[0m"
BOLD="\e[1m"
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"

bin="$HOME/.local/bin"
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

printf "Welcome to the ${BOLD}${app}${NF} installer\n"
printf "This installer will guide you through the process of installing ${BOLD}${app}${NF} on your system\n"
printf "${BLUE}Press any key to continue${NF}\n"
"$skip_prompts" || read -sr -n 1

echo "Checking for '${app}'..."

which "$app" > /dev/null 2>&1

if [ "$?" -eq '0' ]; then
  printf "${YELLOW}'${app}' found. Uninstall by running the uninstall script.${NF}\n"
  exit 1
fi

echo "'${app}' not found. Installing '${app}'..."

while true; do
  printf "${BLUE}Enter the path where you would like to install '${app}' (default: '${bin}'): ${NF}"
  "$skip_prompts" || read tmp

  [ -n "$tmp" ] && bin="$tmp"
  printf "${BLUE}'${app}' will be added to '${bin}' (y/N)${NF}"
  "$skip_prompts" && ans='y' || read -sr -n 1 ans
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
data="${HOME}/.${app}"
mkdir -p "$data"
cp -a "$(dirname "$0")/data/." "$data"
cp $(dirname "$0")/*.md "$data"
cp "$(dirname "$0")/.app" "$data"
cp "$(dirname "$0")/uninstall.sh" "$data"
chmod u+x "${bin}/${app}"

# Get jq
tmp="${TMPDIR-/tmp}"
jq="${tmp}/jq"

os="$(grep -q 'darwin' <<<"$OSTYPE" && echo 'osx-amd64' || echo 'linux64')"
jq_remote="https://github.com/stedolan/jq/releases/download/jq-1.6/jq-${os}"
curl -sL "$jq_remote" -o "$jq"
chmod u+x "$jq"

# Device login
while true; do
  echo "Retrieving token for updating gacp..."

  res="$(curl -sX POST -H 'Content-Type: application/json' -H 'Accept: application/json' --data "{\
    \"client_id\": \"$(<"${data}/client")\" \
  }" 'https://github.com/login/device/code')"

  device_code="$("$jq" -r '.device_code' <<<"$res")"
  user_code="$("$jq" -r '.user_code' <<<"$res")"
  verification_uri="$("$jq" -r '.verification_uri' <<<"$res")"
  expires_in="$("$jq" -r '.expires_in' <<<"$res")"
  interval="$("$jq" -r '.interval' <<<"$res")"

  printf "${BLUE}Please open '${verification_uri}' in your browser and enter the code: '${user_code}'${NF}\n"

  while [ "$expires_in" -gt 0 ]; do
    res="$(curl -sX POST -H 'Content-Type: application/json' -H 'Accept: application/json' --data "{\
      \"client_id\": \"$(<"${data}/client")\", \
      \"device_code\": \"${device_code}\", \
      \"grant_type\": \"urn:ietf:params:oauth:grant-type:device_code\"
    }" 'https://github.com/login/oauth/access_token')"
    token="$("$jq" -r '.access_token' <<<"$res")"

    if [ "$token" != 'null' ]; then
      echo "$token" >> "${data}/.token"
      break
    fi

    sleep "$interval"
    expires_in=$((expires_in - time))
  done

  [ "$token" != 'null' ] && break
done

printf "${GREEN}Token successfully configured${NF}\n"

printf "${GREEN}${app} successfully installed.${NF}\n"
printf "${GREEN}Run it using '${app}' or create an alias for it in your shell config file.${NF}\n"

if [ "$configured" -ne '0' ]; then
  printf "${BLUE}You may need to restart your terminal or run 'source ${shell_config}' first${NF}\n"
else
  printf "${YELLOW}Could not find a recognized shell config file${NF}\n"
  printf "${YELLOW}If you already have one, then please add \"export PATH=${bin}:\$PATH\" to it${NF}\n"
  printf "${YELLOW}If not, you will need to create on and add the above line to it${NF}\n"
  printf "${BLUE}After reading the above note, press any key to continue${NF}\n"
  "$skip_prompts" || read -sr -n 1
fi
