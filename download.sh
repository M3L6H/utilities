#!/bin/bash

authentication="$1"
escape_char=$(printf '\u1b')
tmp='/var/tmp'
jq="${tmp}/jq"
repo='https://api.github.com/repos/m3l6h/utilities'
# repo='https://api.github.com/repos/stedolan/jq'
releases="${repo}/releases"

function gcurl {
  [ -z "$authentication" ] && \
    curl -sH 'Accept: application/vnd.github.v3+json' $@ || \
    curl -u "$authentication" -sH 'Accept: application/vnd.github.v3+json' $@
}

function get_jq {
  local jq_remote=$(gcurl https://api.github.com/repos/stedolan/jq/releases/latest | sed -n 's/^.*"browser_download_url": "\(\S*linux64\).*$/\1/p')
  curl -sL "$jq_remote" -o "$jq"
  chmod u+x "$jq"
}

function get_util {
  (cd "$tmp" && curl -sL "$1" -o "${2}.tar.gz")
  echo "${tmp}/${2}.tar.gz"
}

function print_scr {
  clear
  printf "Select the utilities you would like to install\n"
  printf "Navigate with the arrow keys\n"
  printf "Use A to select all utilities\n"
  printf "Use S to toggle a particular utility\n"
  printf "Use D to select all utilities\n"
  printf "Use Q to quit this menu\n"
  printf "Use Enter to confirm your selection\n"
  offset=7

  numlines=0

  local util
  for util in "${names[@]}"; do
    printf "[ ] ${util}"
    "${prerelease[$numlines]}" && printf ' (prerelease)'
    printf '\n'
    numlines=$((numlines + 1))
  done

  line=1
  echo -en "\033[$((offset + line));2H"
}

function exit_handler {
  clear
  [ -z "$1" ] && printf 'Exiting cleanly...\n' || printf "$1"
  exit 0
}

function main {
  get_jq
  local releases="$(gcurl "$releases")"
  IFS=$'\n' names=($("$jq" -r '.[].name' <<<"$releases"))
  IFS=$'\n' prerelease=($("$jq" -r '.[].prerelease' <<<"$releases"))
  IFS=$'\n' urls=($("$jq" -r '.[].assets | .[0].browser_download_url' <<<"$releases"))
  local toggles=( )

  for dump in "${names[@]}"; do toggles+=( false ); done

  local key
  print_scr
  while read -sn1 key; do
    [ "$key" = "$escape_char" ] && read -sn2 key
    case "$key" in
      'a')
        local i=0
        for t in "${toggles[@]}"; do
          toggles[$i]=true
          i=$((i+1))
          echo -en "\033[$((i + offset));2Hx"
        done
      ;;
      'd')
        local i=0
        for t in "${toggles[@]}"; do
          toggles[$i]=false
          i=$((i+1))
          echo -en "\033[$((i + offset));2H "
        done
      ;;
      'q') exit_handler 'Download aborted\n' ;;
      's')
        $(${toggles[$((line - 1))]}) && toggles[$((line - 1))]=false || toggles[$((line - 1))]=true
        $(${toggles[$((line - 1))]}) && printf 'x' || printf ' '
      ;;
      '[A') line=$((line - 1)) && [ 1 -ge "$line" ] && line=1 ;;
      '[B') line=$((line + 1)) && [ "$numlines" -lt "$line" ] && line="$numlines" ;;
      '') break ;;
      *) ;;
    esac
    echo -en "\033[$((line + offset));2H"
  done

  clear

  local i=0
  for t in "${toggles[@]}"; do
    if "$t"; then
      printf "Installing ${names[$i]}...\n"
      mkdir -p "${tmp}/${names[$i]}" 2>/dev/null
      tar -xzf "$(get_util "${urls[$i]}" "${names[$i]}")" -C "${tmp}/${names[$i]}"
      (cd "${tmp}/${names[$i]}" && "./install.sh")
    fi
    i=$((i + 1))
  done
}

trap exit_handler SIGINT
main
