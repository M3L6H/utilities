#!/bin/bash

HARDLIMIT=10

data="${HOME}/.gacp"

usage="Usage: gacp -m <commit message> [files to commit]"

read -r -d '' help <<EOF
${usage}

Subcommands:
  c         Alias for config
  config    Configure gacp. Use 'gacp config -h' for more info
  configure Alias for config
  u         Alias for update
  update    Update gacp. Use 'gacp update -h' for more info
  upgrade   Alias for update

Options:
  -f  Force gacp to ignore its limits. This does NOT run a force push. Instead,
      gacp will ignore things such as the limit on number of files to push.
  -h  Print help
  -l  Sets a limit on the number of files to commit before 'gacp' aborts
  -m  Specify commit message
  -u  Automatically run with '--set-upstream origin <current branch>'

Details:
  https://github.com/M3L6H/utilities/tree/gacp
EOF

usage_config="Usage: gacp config [-l limit]"

read -r -d '' help_config <<EOF
Usage: gacp config [-l limit] [-u true/false]

Aliases: c, configure

Description:
  Configures gacp. When run without flags, prints out the current gacp
  configuration.

Options:
  -h  Print help
  -l  Configure the default file limit
  -u  Configure whether gacp should automatically update
EOF

usage_update="Usage: gacp update [-v version]"

read -r -d '' help_update <<EOF
Usage: gacp update [-v version]
       gacp update -l

Aliases: u, upgrade

Description:
  Updates gacp. When run without flags, updates to the latest gacp version. If
  the -v flag was passed, it will update to the specified version.
  List available versions by running it with -l.

Options:
  -h  Print help
  -l  List available versions
  -v  Update to a specific version
EOF

read -r -d '' limitwarning <<EOF
You are seeing this because you have tried to set the file limit for gacp to a
number greater than ${HARDLIMIT}.

The point of the file limit is to prevent you from accidentally pushing an
inordinate number of files to source control. For example, in the case where you
forgot to gitignore your node_modules folder.

As a tool, gacp is designed to make small incremental changes quicker and easier
to push to source control. If you are going to push a large number of files at
once, you should probably use traditional git commands.

However, in the case that you want to have your way, the -f flag exists for this
very purpose.
EOF

# Colors
NF="\e[0m"
GREEN="\e[32m"
RED="\e[31m"

# Global vars
tmp='/var/tmp'
jq="${tmp}/jq"

OPTIND=1 # Used to parse arguments after flags

configure=false
force=false
limit=""
message=""
setUpstream=false

# Functions
function help_msg {
  echo "$help" | less
  exit 0
}

function unrecognized_argument {
  echo "Unrecognized argument"
  echo "$usage"
  exit 1
}

function gcurl {
  local token="$(<"${data}/.token")"

  if [ -z "$token" ]; then
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
  fi

  curl -sH "Authorization: Bearer ${token}" -H 'Accept: application/vnd.github.v3+json' "$@"
}

function get_jq {
  jq_remote='https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64'
  curl -sL "$jq_remote" -o "$jq"
  chmod u+x "$jq"
}

function configure {
  configured=false

  if [ -n "$limit" ]; then
    if [ "$limit" -gt "$HARDLIMIT" ]; then
      echo "$limitwarning"
      exit 1
    elif [ "$limit" -lt 1 ]; then
      echo "Limit cannot be less than 1! Got '${limit}'."
      exit 1
    fi

    echo "$limit" > "${data}/.limit"
    printf "${GREEN}Default limit set to '${limit}'${NF}\n"
    configured=true
  fi

  if [ -n "$update_automatically" ]; then
    if [ "$update_automatically" != 'true' ] && [ "$update_automatically" != 'false' ]; then
      printf "${RED}The update automatically flag can only be set to 'true' or 'false'${NF}\n"
      exit 1
    fi

    echo "$update_automatically" > "${data}/.update"
    printf "${GREEN}Update automatically set to '${update_automatically}'${NF}\n"
    configured=true
  fi

  if ! "$configured"; then
    echo "Printing current configuration..."
    echo "limit: $(<"$data/.limit")"
    echo "update_automatically: $(<"$data/.update")"
  fi
  exit 0
}

function get_versions {
  get_jq
  res="$(gcurl "https://api.github.com/repos/$(<"${data}/remote")/releases")"
  IFS=$'\n' versions=($("$jq" -r '.[].tag_name' <<<"$res" | grep 'gacp'))
}

function random {
  tr -dc A-Za-z0-9 </dev/urandom | head -c 13
  echo ''
}

# Expects the following args:
#   $1: version a
#   $2: version b
# Performs the comparison a > b on major.minor.patch semantic versions
function greater_than {
  local a="$1" b="$2"
  local major_a="${a%.*.*}" major_b="${b%.*.*}"
  local suffix_a="${a#*.}" suffix_b="${b#*.}"
  local minor_a="${suffix_a%.*}" minor_b="${suffix_b%.*}"
  local patch_a="${suffix_a#*.}" patch_b="${suffix_b#*.}"

  [ "$major_a" -gt "$major_b" ] && return 0
  [ "$minor_a" -gt "$minor_b" ] && return 0
  [ "$patch_a" -gt "$patch_b" ] && return 0

  return 1
}

function update {
  get_versions
  [ -z "$version" ] && version="${versions[0]}"

  if [ "${version#*-v}" = "$(<"${data}/version")" ]; then
    printf "${YELLOW}Version ${version#*-v} of gapc is already installed${NF}\n"
    return 1
  fi

  download_url="$("$jq" -r '.[].assets[0].browser_download_url' <<<"$res" | grep "${version//-v/-}")"
  cd "${tmp}"
  curl -sL "$download_url" -o "gacp.tar.gz"
  local gacp="${tmp}/$(random)"
  mkdir -p "$gacp"
  tar -xzf "${tmp}/gacp.tar.gz" -C "$gacp"

  greater_than "${version#*-v}" "$(<"${data}/version")" && \
    "${gacp}/upgrade.sh" || \
    "${gacp}/downgrade.sh"

  "${gacp}/reinstall.sh" -y
}

function main {
  if "$(<"${data}/.update")"; then
    update "$@"
    gacp "$@"
    exit "$?"
  fi

  if [ -z "$message" ]; then
    echo "Commit message is required!"
    echo "$usage"
    exit 1
  fi

  # Get default values for arguments
  [ -z "$limit" ] && limit="$(<"$data/.limit")"

  if [ "$limit" -gt "$HARDLIMIT" ]; then
    echo "$limitwarning"
    exit 1
  fi

  # Shift off the already-parsed arguments
  shift $((OPTIND-1))
  [ "${1:-}" = "--" ] && shift

  if [ -z "$*" ]; then
    git add .
  else
    git add "$@"
  fi

  numfiles=`git diff --cached --numstat | wc -l | xargs`

  if ! $force && [ "$numfiles" -gt "$limit" ]; then
    printf "${RED}gacp aborted!${NF}\n"
    printf "${RED}${numfiles} were staged for commit, but only ${limit} are allowed${NF}\n"
    git reset
    exit 1
  fi

  git commit -m "$message"

  if ! $setUpstream; then
    git push
  else
    git push --set-upstream origin "$(git branch --show-current)"
  fi

}

# Parse sub-commands
OPTIND=2
case "$1" in
  'c'|'config'|'configure')
    operation='configure'
    help="$help_config"
    usage="$usage_config"

    while getopts ":hl:u:" opt; do
      case "$opt" in
      h) help_msg ;;
      l) limit="$OPTARG" ;;
      u) update_automatically="$OPTARG" ;;
      esac
    done
  ;;
  'u'|'update'|'upgrade')
    operation='update'
    help="$help_update"
    usage="$usage_update"

    while getopts ":hlv:" opt; do
      case "$opt" in
      h) help_msg ;;
      l)
        get_versions
        for version in "${versions[@]}"; do
          grep -q "$(<${data}/version)" <<<"$version" && printf "*"
          printf "${version}\n"
        done
        exit 0
      ;;
      v) version="$OPTARG" ;;
      *) unrecognized_argument ;;
      esac
    done
  ;;
  *)
    OPTIND=1

    while getopts ":cfhl:m:uv" opt; do
      case "$opt" in
      c)
        cat "${data}/CHANGELOG.md" | less
        exit 0
      ;;
      f) force=true ;;
      h) help_msg ;;
      l) limit="$OPTARG" ;;
      m) message="$OPTARG" ;;
      u) setUpstream=true ;;
      v)
        cat "${data}/version"
        exit 0
      ;;
      *) unrecognized_argument ;;
      esac
    done
  ;;
esac

case "$operation" in
  configure) configure "$@" ;;
  update) update "$@" ;;
  *) main "$@" ;;
esac
