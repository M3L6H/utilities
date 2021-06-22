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

read -r -d '' help_config <<EOF
Usage: gacp config [-l limit]

Aliases: c, configure

Description:
  Configures gacp. When run without flags, prints out the current gacp
  configuration.

Options:
  -h  Print help
  -l  Configure the default file limit
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

# Script start
OPTIND=1 # Used to parse arguments after flags

configure=false
force=false
limit=""
message=""
setUpstream=false

# Parse sub-commands
OPTIND=2
case "$1" in
  'c'|'config'|'configure')
    configure=true
    help="$help_config"
  ;;
  *) OPTIND=1 ;;
esac

# Parse args
while getopts ":cfhl:m:uv" opt; do
  case "$opt" in
  c)
    cat "${data}/CHANGELOG.md" | less
    exit 0
  ;;
  f) force=true ;;
  h)
    echo "$help" | less
    exit 0
  ;;
  l) limit="$OPTARG" ;;
  m) message="$OPTARG" ;;
  u) setUpstream=true ;;
  v)
    cat "${data}/version"
    exit 0
  ;;
  *)
    echo "Unrecognized argument"
    echo "$usage"
    exit 1
  ;;
  esac
done

if $configure; then
  configured=false
  if [ -n "$limit" ]; then
    if [ "$limit" -gt "$HARDLIMIT" ]; then
      echo "$limitwarning"
      exit 1
    elif [ "$limit" -lt 1 ]; then
      echo "Limit cannot be less than 1! Got '${limit}'."
      exit 1
    fi

    echo "$limit" > "$data/.limit"
    printf "${GREEN}Default limit set to '${limit}'${NF}\n"
    configured=true
  fi

  if ! "$configured"; then
    echo "Printing current configuration..."
    echo "limit: $(<"$data/.limit")"
  fi
  exit 0
elif [ -z "$message" ]; then
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
  git add $*
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
