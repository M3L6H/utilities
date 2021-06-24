#!/bin/bash

echo "Upgrading to $(<"$(dirname "$0")/data/version")..."
[ -f "${HOME}/.gacp/.update" ] || cp "$(dirname "$0")/data/.update" "${HOME}/.gacp/"
