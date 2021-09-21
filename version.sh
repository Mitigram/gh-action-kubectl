#!/bin/sh

# This script will download the kubectl version for a given release channel and
# keep it in cache for some time. The value in cache is automatically renewed.
# The script prints out the version number for that channel.

set -eu

# Location of user-specific state file, according to the XDG specification
XDG_STATE_HOME=${XDG_STATE_HOME:-"${HOME}/.local/state"}

# Set this to 1 for more verbosity (on stderr)
VERSION_VERBOSE=${VERSION_VERBOSE:-0}

# Location of the kubectl version discovery cache (a directory, that will be
# created if necessary)
VERSION_CACHE=${VERSION_CACHE:-"${XDG_STATE_HOME%%*/}/kubectl"}

# Version channel to follow
VERSION_CHANNEL=${VERSION_CHANNEL:-"stable"}

# Root URL for kubectl binary download.
VERSION_ROOTURL=${VERSION_ROOTURL:-"https://storage.googleapis.com/kubernetes-release/release"}

# Period to keep version information in cache without even triggering a download
# attempt. Default to 0, always download. This can be a human-readable period
# such as 3d (3 days), etc.
VERSION_KEEP=${VERSION_KEEP:-0}

# This uses the comments behind the options to show the help. Not extremly
# correct, but effective and simple.
usage() {
  echo "$0 discovers (and cache) the kubectl version for a given release channel:" && \
    grep "[[:space:]].)\ #" "$0" |
    sed 's/#//' |
    sed -r 's/([a-z])\)/-\1/'
  exit "${1:-0}"
}

while getopts "c:l:r:k:vh-" opt; do
  case "$opt" in
    c) # Location of cache file for version storage.
      VERSION_CACHE=$OPTARG;;
    l) # Channel to use for kubectl
      VERSION_CHANNEL=$OPTARG;;
    r) # Root URL to use for all kubectl binaries (and channel information!)
      VERSION_ROOTURL=$OPTARG;;
    k) # Length to keep version information for that channel.
      VERSION_KEEP=$OPTARG;;
    v) # Turn on verbosity
      VERSION_VERBOSE=1;;
    h) # Print help and exit
      usage;;
    -)
      break;;
    *)
      usage 1;;
  esac
done
shift $((OPTIND-1))


verbose() {
  if [ "$VERSION_VERBOSE" = "1" ]; then
    printf %s\\n "$1" >&2
  fi
}

error() {
  printf %s\\n "$1" >&2
  exit 1
}

download() {
  verbose "Downloading $1"
  if command -v curl >&2 >/dev/null; then
    curl -sSL "$1" > "$2"
  elif command -v wget >&2 >/dev/null; then
    wget -q -O - "$1" > "$2"
  else
    error "Can neither find curl, nor wget for downloading"
  fi
}

# Return the approx. number of seconds for the human-readable period passed as a
# parameter
howlong() {
  # shellcheck disable=SC3043 # local is implemented in most shells
  local len || true
  if printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*[yY]'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*[yY].*/\1/p')
    # shellcheck disable=SC2003
    expr "$len" \* 31536000
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*[Mm][Oo]'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Mm][Oo].*/\1/p')
    # shellcheck disable=SC2003
    expr "$len" \* 2592000
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*[Mm][Ii]'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Mm][Ii].*/\1/p')
    # shellcheck disable=SC2003
    expr "$len" \* 60
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*m'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*m.*/\1/p')
    # shellcheck disable=SC2003
    expr "$len" \* 2592000
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*[Ww]'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Ww].*/\1/p')
    # shellcheck disable=SC2003
    expr "$len" \* 604800
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*[Dd]'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Dd].*/\1/p')
    # shellcheck disable=SC2003
    expr "$len" \* 86400
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*[Hh]'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Hh].*/\1/p')
    # shellcheck disable=SC2003
    expr "$len" \* 3600
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*M'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*M.*/\1/p')
    # shellcheck disable=SC2003
    expr "$len" \* 60
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+[[:space:]]*[Ss]'; then
    len=$(printf %s\\n "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Ss].*/\1/p')
    echo "$len"
  elif printf %s\\n "$1"|grep -Eqo '^[0-9]+'; then
    printf %s\\n "$1"
  fi
}

cache() {
  verbose "Caching version from ${VERSION_ROOTURL%%*/}/${VERSION_CHANNEL}.txt"
  download "${VERSION_ROOTURL%%*/}/${VERSION_CHANNEL}.txt" "${VERSION_CACHE%%*/}/${VERSION_CHANNEL}.txt"
}

if ! [ -d "$VERSION_CACHE" ]; then
  verbose "Creating version cache directory $VERSION_CACHE"
  mkdir -p "$VERSION_CACHE"
fi

VERSION_KEEP=$(howlong "$VERSION_KEEP")
if [ -f "${VERSION_CACHE%%*/}/${VERSION_CHANNEL}.txt" ]; then
  if [ -n "$VERSION_KEEP" ] && [ "$VERSION_KEEP" -gt "0" ]; then
    last=$(stat -c "%Z" "${VERSION_CACHE%%*/}/${VERSION_CHANNEL}.txt")
    # Get the current number of seconds since the epoch, POSIX compliant:
    # https://stackoverflow.com/a/12746260
    now=$(PATH=$(getconf PATH) awk 'BEGIN{srand();print srand()}')
    elapsed=$(( now - last ))
    if [ "$elapsed" -gt "$VERSION_KEEP" ]; then
      verbose "File at ${VERSION_CACHE%%*/}/${VERSION_CHANNEL}.txt $elapsed secs. (too) old, downloading again."
      cache
    else
      verbose "File at ${VERSION_CACHE%%*/}/${VERSION_CHANNEL}.txt $elapsed secs. old, keeping."
    fi
  else
    verbose "Cache time $VERSION_KEEP negative (or invalid), installing"
    cache
  fi
else
  verbose "No file at ${VERSION_CACHE%%*/}/${VERSION_CHANNEL}.txt, installing"
  cache
fi

# Print out version (from cache)
[ -f "${VERSION_CACHE%%*/}/${VERSION_CHANNEL}.txt" ] && cat "${VERSION_CACHE%%*/}/${VERSION_CHANNEL}.txt"
