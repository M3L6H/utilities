#!/bin/bash

echo "Upgrading to $(<"$(dirname "$0")/data/version")..."
cp "$(dirname "$0")/data/.update" "${HOME}/.gacp/"
