#!/usr/bin/env bash
# Source this from a ProjectGero checkout before build/envsetup.sh.
PROJECTGERO_TOOLS_DIR="${PROJECTGERO_TOOLS_DIR:-$HOME/.local/projectgero-tools}"
export PROJECTGERO_TOOLS_DIR
export PATH="$PROJECTGERO_TOOLS_DIR/python2/bin:$PATH"
export LC_ALL=C
export LANG=C
