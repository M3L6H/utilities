#!/bin/bash

authentication="$1"
escape_char=$(printf '\u1b')
tmp="${TMPDIR-/tmp}"
jq="${tmp}/jq"
repo='https://api.github.com/repos/m3l6h/utilities'
releases="${repo}/releases"
height="$(tput lines)"
width="$(tput cols)"

instructions=("Select the utilities you would like to install" "Navigate with the arrow keys" "Press A to select the latest version of each utility" "Press S to toggle a particular utility" "Press D to select all utilities" "Press Q to quit this menu" "Press Enter to confirm your selection" " ")
offset="${#instructions[@]}"

function gcurl {
  [ -z "$authentication" ] && \
    curl -sH 'Accept: application/vnd.github.v3+json' $@ || \
    curl -u "$authentication" -sH 'Accept: application/vnd.github.v3+json' $@
}

function get_jq {
  local os="$(grep -q 'darwin' <<<"$OSTYPE" && echo 'osx-amd64' || echo 'linux64')"
  local jq_remote=$(gcurl https://api.github.com/repos/stedolan/jq/releases/latest | sed -nE "s/^.*\"browser_download_url\": \"(.*${os}).*$/\1/p")
  curl -sL "$jq_remote" -o "$jq"
  chmod u+x "$jq"
}

function get_util {
  (cd "$tmp" && curl -sL "$1" -o "${2}.tar.gz")
  echo "${tmp}/${2}.tar.gz"
}

# Expects the following:
#   $1 - String to print
#   $2 - (Optional) Color
function println {
  local strlen="${#1}"
  local offset=1 numlines=0 substr cutpoint

  [ -n "$2" ] && echo -en "$2"

  while true; do
    cutpoint=$((offset + width - 1))

    while [ "$cutpoint" -ge "$offset" ]; do
      [ "$cutpoint" -ge "$strlen" ] && break
      [ "$(cut -c "${cutpoint}-${cutpoint}" <<<"$1")" = ' ' ] && break
      cutpoint=$((cutpoint - 1))
    done

    [ "$cutpoint" -lt "$offset" ] && cutpoint=$((offset + width - 1))

    substr="$(cut -c "${offset}-${cutpoint}" <<<"$1")"

    [ -z "$substr" ] && break
    printf "${substr}"
    numlines=$((numlines + 1))
    offset=$((offset + cutpoint))
    [ "$offset" -le "$strlen" ] && echo
  done

  [ -n "$2" ] && echo -en "\e[0m"

  return "$numlines"
}

# Expects the following:
#   $1 - The line the user is on
function print_list {
  if [ "$height" -le "$offset" ]; then
    clear
    println "Terminal window is not tall enough!\n"
    exit 1
  fi

  local line="$1"
  local space=$((height - offset))
  local hidden=$((line - space))
  [ "$hidden" -lt 0 ] && hidden=0
  local i="$hidden" util count=1 str

  while [ "$i" -lt "$numlines" ]; do
    util="${names[i]}"
    str="[$($(${toggles[i]}) && echo 'x' || echo ' ')] ${util}$("${latest[$i]}" && echo ' (latest)')$("${prerelease[$i]}" && echo ' (prerelease)')"
    [ "${#str}" -gt "$width" ] && str="$(cut -c "1-$((width-3))" <<<"$str")..."
    println "$str"
    i=$((i + 1))
    count=$((count + 1))
    [ "$count" -gt "$space" ] && break || echo
  done

  echo -en "\033[$((offset + line - hidden));2H"
}

function print_scr {
  clear
  local instruction
  offset=0
  for instruction in "${instructions[@]}"; do
    println "${instruction}\n"
    local lines="$?"
    offset=$((offset + lines))
  done
}

function exit_handler {
  clear
  [ -z "$1" ] && printf 'Exiting cleanly...\n' || printf "$1"
  exit 0
}

function main {
  if [ "$width" -lt 30 ]; then
    println "Terminal must be at least 30 characters wide!\n"
    exit 1
  fi

  get_jq
  local releases="$(gcurl "$releases")"
  IFS=$'\n' names=($("$jq" -r '.[].name' <<<"$releases"))
  IFS=$'\n' prerelease=($("$jq" -r '.[].prerelease' <<<"$releases"))
  IFS=$'\n' urls=($("$jq" -r '.[].assets | .[0].browser_download_url' <<<"$releases"))
  numlines="${#names[@]}"
  toggles=( )
  latest=( )

  local found_latest name
  for name in "${names[@]}"; do
    toggles+=( false )
    name="$(awk '{ print $1; }' <<<"$name")"
    if grep -q "$name" <<<"$found_latest"; then
      latest+=( false )
    else
      latest+=( true )
      found_latest="${found_latest}:${name}"
    fi
  done

  local key line=1
  print_scr
  print_list "$line"
  while read -sn1 key; do
    [ "$key" = "$escape_char" ] && read -sn2 key
    case "$key" in
      'a')
        local i=0
        for t in "${toggles[@]}"; do
          "${latest[i]}" && toggles[$i]=true
          i=$((i+1))
        done
      ;;
      'd')
        local i=0
        for t in "${toggles[@]}"; do
          toggles[$i]=false
          i=$((i+1))
        done
      ;;
      'q') exit_handler 'Download aborted\n' ;;
      's')
        $(${toggles[$((line - 1))]}) && toggles[$((line - 1))]=false || toggles[$((line - 1))]=true
      ;;
      '[A') line=$((line - 1)) && [ 1 -ge "$line" ] && line=1 ;;
      '[B') line=$((line + 1)) && [ "$numlines" -lt "$line" ] && line="$numlines" ;;
      '') break ;;
      *) ;;
    esac
    echo -en "\033[$((offset + 1));1H"
    print_list "$line"
  done

  clear

  local i=0
  for t in "${toggles[@]}"; do
    if "$t"; then
      printf "Installing ${names[$i]}...\n"
      mkdir -p "${tmp}/${names[$i]}" 2>/dev/null
      tar -xzf "$(get_util "${urls[$i]}" "${names[$i]}")" -C "${tmp}/${names[$i]}"
      (cd "${tmp}/${names[$i]}" && ./install.sh -y)
    fi
    i=$((i + 1))
  done
}

trap exit_handler SIGINT
main
