#!/bin/sh

set -eu

# Set this to 1 for more verbosity (on stderr)
KUBECTL_VERBOSE=${KUBECTL_VERBOSE:-0}

KUBECTL_BASE64=${KUBECTL_BASE64:-0}

KUBECTL_KUBECONFIG=${KUBECTL_KUBECONFIG:-}

KUBECTL_HOSTNAME=${KUBECTL_HOSTNAME:-}
KUBECTL_CERTIFICATE=${KUBECTL_CERTIFICATE:-}

KUBECTL_TOKEN=${KUBECTL_TOKEN:-}
KUBECTL_USERNAME=${KUBECTL_USERNAME:-}
KUBECTL_PASSWORD=${KUBECTL_PASSWORD:-}

KUBECTL_BINARY=${KUBECTL_BINARY:-"kubectl"}

usage() {
  # This uses the comments behind the options to show the help. Not extremly
  # correct, but effective and simple.
  echo "$0 installs kubectl auth context and runs kubectl with all remaining args:" && \
    grep "[[:space:]].)\ #" "$0" |
    sed 's/#//' |
    sed -r 's/([a-z])\)/-\1/'
  exit "${1:-0}"
}

while getopts "k:s:c:t:u:p:6b:vh-" opt; do
  case "$opt" in
    v) # Turn on verbosity
      KUBECTL_VERBOSE=1;;
    6) # Values of -k, -c options will all be decoded from base64, default is to guess.
      KUBECTL_VERBOSE=1;;
    k) # kubeconfig to use, base64 encoding preferred.
      KUBECTL_KUBECONFIG=$OPTARG;;
    s) # Server hostname.
      KUBECTL_HOSTNAME=$OPTARG;;
    c) # CA cerficate to use, base64 encoding preferred.
      KUBECTL_CERTIFICATE=$OPTARG;;
    t) # Token to use for user authentication.
      KUBECTL_TOKEN=$OPTARG;;
    u) # Username to use for authentication.
      KUBECTL_USERNAME=$OPTARG;;
    p) # Password to use for authentication.
      KUBECTL_PASSWORD=$OPTARG;;
    b) # Full path to kubectl binary, or name of binaray to look in PATH
      KUBECTL_BINARY=$OPTARG;;
    h) # Print help and exit
      usage;;
    -)
      break;;
    *)
      usage 1;;
  esac
done
shift $((OPTIND-1))


_verbose() {
  if [ "$KUBECTL_VERBOSE" = "1" ]; then
    printf %s\\n "$1" >&2
  fi
}

_error() {
  printf %s\\n "$1" >&2
  exit 1
}

_base64encoded() {
  test -z "$(printf %s\\n "$1" | tr -d '[A-Za-z0-9/=\n')"
}

_decode() {
  if [ "$KUBECTL_BASE64" = "1" ]; then
    _verbose "base64 decoding to ${tmpdir}/${2}"
    printf %s\\n "$1" | base64 -d > "${tmpdir}/${2}"
    chmod og-rw "${tmpdir}/${2}"
    printf %s\\n "${tmpdir}/${2}"
  elif [ -f "$1" ]; then
    _verbose "using file at $1"
    printf %s\\n "$1"
  elif _base64encoded "$1"; then
    _verbose "base64 decoding to ${tmpdir}/${2}"
    printf %s\\n "$1" | base64 -d > "${tmpdir}/${2}"
    chmod og-rw "${tmpdir}/${2}"
    printf %s\\n "${tmpdir}/${2}"
  else
    _verbose "inlining to ${tmpdir}/${2}"
    printf %s\\n "$1" > "${tmpdir}/${2}"
    chmod og-rw "${tmpdir}/${2}"
    printf %s\\n "${tmpdir}/${2}"
  fi
}

opts=                              ; # List of CLI options to kubectl
tmpdir=$(mktemp -d kubectl-XXXXXX) ; # Temporary directory for file storage

if [ -n "$KUBECTL_KUBECONFIG" ]; then
  _verbose "Using kubeconfig information for cluster access and auth"
  opts="--kubeconfig \"$(_decode "$KUBECTL_KUBECONFIG" kubeconfig.yml)\""
elif [ -z "$KUBECTL_HOSTNAME" ] || [ -z "$KUBECTL_CERTIFICATE" ]; then
  _error "No cluster information provided"
elif [ -z "$KUBECTL_TOKEN" ]; then
  if [ -z "$KUBECTL_USERNAME" ] && [ -z "$KUBECTL_PASSWORD" ]; then
    _error "No user auth provided"
  else
    _verbose "Using token for cluster access and auth"
    opts="--server \"https://${KUBECTL_HOSTNAME}\" \
          --certificate \"$(_decode "$KUBECTL_CERTIFICATE" ca.crt)\" \
          --username \"$KUBECTL_USERNAME\" \
          --password \"$KUBECTL_PASSWORD\""
  fi
else
    _verbose "Using username/password for cluster access and auth"
    opts="--server \"https://${KUBECTL_HOSTNAME}\" \
          --certificate \"$(_decode "$KUBECTL_CERTIFICATE" ca.crt)\" \
          --token \"$KUBECTL_TOKEN\""
fi

# Transform options and remaining arguments into a single array and call kubectl
# with the (new) array.
set -- "$opts" "$@"
"$KUBECTL_BINARY" "$@"

# Cleanup
rm -rf "$tmpdir"