#!/usr/bin/env bash

set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

if [[ -n "$(git status --porcelain)" ]]; then
  printf '%s\n' '[ai-dotfiles] working tree dirty at session end - consider /checkpoint' >&2
fi

exit 0
