#!/bin/bash

echo "Downgrading to $(<"$(dirname "$0")/data/version")..."
rm "${HOME}/.gacp/.update"
