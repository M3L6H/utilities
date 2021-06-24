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
  uninstall Uninstall gacp. Use 'gacp uninstall -h' for more info
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

usage_uninstall="Usage: gacp uninstall"

read -r -d '' help_uninstall <<EOF
Usage: gacp uninstall

Description:
  Removes gacp completely from your system. You will lose all your configs.

Options:
  -h  Print help
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
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"

# Global vars
tmp="${TMPDIR-/tmp}"
jq="${tmp}/jq"

OPTIND=1 # Used to parse arguments after flags

backup=()
originals=()
configure=false
config="./.gacprc"
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
  local os="$(grep -q 'darwin' <<<"$OSTYPE" && echo 'osx-amd64' || echo 'linux64')"
  local jq_remote="https://github.com/stedolan/jq/releases/download/jq-1.6/jq-${os}"
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

function latest_version {
  get_versions
  echo "${versions[0]#*-v}"
}

function random {
  LC_CTYPE=C tr -dc A-Za-z0-9 </dev/urandom | head -c 13
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

function list_versions {
  get_versions
  for version in "${versions[@]}"; do
    grep -q "$(<${data}/version)" <<<"$version" && printf "${GREEN}*"
    printf "${version}${NF}\n"
  done
}

function update {
  get_versions
  [ -z "$version" ] && version="${versions[0]}"

  if [ "${version#*-v}" = "$(<"${data}/version")" ]; then
    printf "${YELLOW}Version ${version#*-v} of gapc is already installed${NF}\n"
    return 1
  fi

  download_url="$("$jq" -r '.[].assets[0].browser_download_url' <<<"$res" | grep "${version//-v/-}")"

  local base_dir="$PWD"
  cd "${tmp}"
  curl -sL "$download_url" -o "gacp.tar.gz"
  local gacp="${tmp}/$(random)"
  mkdir -p "$gacp"
  tar -xzf "${tmp}/gacp.tar.gz" -C "$gacp"

  greater_than "${version#*-v}" "$(<"${data}/version")" && \
    "${gacp}/upgrade.sh" || \
    "${gacp}/downgrade.sh"

  "${gacp}/reinstall.sh" -y
  cd "$base_dir"
}

# Expects the following arguments:
#   $1: JSON object containing template configuration
# Returns the filled out template
function populate_template {
  local template="$("$jq" -r '.template' <<<"$1")"
  template="$(sed "s/<_msg>/$message/g" <<<"$template")"
  local variable variables i=0 cmd
  IFS=$'\n' variables=($("$jq" -r '.variables[].name' <<<"$1"))

  for variable in "${variables[@]}"; do
    cmd="$("$jq" -r ".variables[${i}].command" <<<"$1")"
    template="$(sed "s/<$variable>/$(eval $cmd)/g" <<<"$template")"
  done

  echo -n "$template"
}

# Expects the following arguments:
#   $1: List of actions to perform
function pre_stage {
  [ -z "$1" ] || [ "$1" = 'null' ] && return 1

  local action actions i=0
  IFS=$'\n' actions=($("$jq" -r '.[].action' <<<"$1"))

  for action in "${actions[@]}"; do
    case "$action" in
    'insert')
      local file="$("$jq" -r ".[${i}].file" <<<"$1")"
      local line="$("$jq" -r ".[${i}].line" <<<"$1")"
      local content="$(populate_template "$("$jq" ".[${i}].content" <<< "$1")")"
      backup+=( "${tmp}/$(random).bckup" )
      original+=( "$file" )
      cp "$file" "$backup"
      ex "$file" <<EOF
${line} insert
${content}
.
xit
EOF
    ;;
    *)
      printf "${YELLOW}Unrecognized action '${action}' in pre-stage${NF}\n"
    ;;
    esac
    i=$((i + 1))
  done
}

function restore {
  git reset
  local file i=0
  for file in "${backup[@]}"; do
    cp "$file" "${original[i]}"
    i=$((i + 1))
  done
}

# Expects the following arguments:
#   $1: List of actions to perform
function pre_commit {
  [ -z "$1" ] || [ "$1" = 'null' ] && return 1

  local action actions i=0
  IFS=$'\n' actions=($("$jq" -r '.[].action' <<<"$1"))

  for action in "${actions[@]}"; do
    case "$action" in
    'insert')
      printf "${RED}Cannot perform insert action in pre-commit step. Perhaps you meant to put it in pre-stage/${NF}\n"
      exit 1
    ;;
    'validate')
      local cmd="$("$jq" -r ".[${i}].command" <<<"$1")"
      if ! eval $cmd; then
        printf "${RED}Failed pre-commit check: '${cmd}'${NF}\n"
        restore
        exit 1
      fi
    ;;
    *)
      printf "${YELLOW}Unrecognized action '${action}' in pre-stage${NF}\n"
    ;;
    esac
    i=$((i + 1))
  done
}

function main {
  if "$(<"${data}/.update")" && update "$@"; then
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

  if [ -f "$config" ]; then
    get_jq
    local pre_stage="$("$jq" '."pre-stage"' <"$config")"
    local pre_commit="$("$jq" '."pre-commit"' <"$config")"
  fi

  pre_stage "$pre_stage"

  if [ -z "$*" ]; then
    git add .
  else
    git add "$@"
  fi

  numfiles=`git diff --cached --numstat | wc -l | xargs`

  if ! $force && [ "$numfiles" -gt "$limit" ]; then
    printf "${RED}gacp aborted!${NF}\n"
    printf "${RED}${numfiles} were staged for commit, but only ${limit} are allowed${NF}\n"
    restore
    exit 1
  fi

  pre_commit "$pre_commit"

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
  'uninstall')
    operation='uninstall'
    help="$help_uninstall"
    usage="$usage_uninstall"

    while getopts ":h" opt; do
      case "$opt" in
      h) help_msg ;;
      *) unrecognized_argument ;;
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
        list_versions | less -rX
        exit 0
      ;;
      v) version="$OPTARG" ;;
      *) unrecognized_argument ;;
      esac
    done
  ;;
  *)
    OPTIND=1

    while getopts ":c:Cfhl:m:uv" opt; do
      case "$opt" in
      c) config="$OPTARG" ;;
      C) config='' ;;
      f) force=true ;;
      h) help_msg ;;
      l) limit="$OPTARG" ;;
      m) message="$OPTARG" ;;
      u) setUpstream=true ;;
      v)
        cat "${data}/version"
        latest="$(latest_version)"
        echo "Latest version is: ${latest}"
        greater_than "$latest" "$(<"${data}/version")" && \
          printf "${BLUE}Upgrade with 'gacp update'${NF}\n"
        exit 0
      ;;
      *) unrecognized_argument ;;
      esac
    done
  ;;
esac

case "$operation" in
  'configure') configure "$@" ;;
  'uninstall')
    "${data}/uninstall.sh"
    exit "$?"
  ;;
  'update') update "$@" ;;
  *) main "$@" ;;
esac
