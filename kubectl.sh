#!/bin/sh

# This script is a wrapper for kubectl. It will authenticate at a cluster, and
# pass all further arguments to the kubectl binary. For some of the options, the
# script will attempt to guess the type of their value and convert to options
# that kubectl understands directly. When such conversions are performed, they
# happen in a temporary directory that is cleaned up after the kubeectl call.

set -eu

# Set this to 1 for more verbosity (on stderr)
KUBECTL_VERBOSE=${KUBECTL_VERBOSE:-0}

# When set to 1, this will force the value of kubeconfig and certificate to be
# understood as being in base64 encoding. Temporary files will be used to decode
# for the time of the kubectl call. When set to 0, the default, the values will
# be guessed: is it a file? Does it only contain base64 characters?
KUBECTL_BASE64=${KUBECTL_BASE64:-0}

# Location of the kubeconfig file. The default is to use the default location
# used by kubectl, making this wrapper a no-op (more or less) when used directly
# from the command line. However, when called from the action, this will end up
# being an empty string if no input was provided.
KUBECTL_KUBECONFIG=${KUBECTL_KUBECONFIG:-${HOME}/.kube/config}

# Hostname and certificate to locate the kubernetes cluster, this is only used
# whenever the value of kubeconfig is empty.
KUBECTL_HOSTNAME=${KUBECTL_HOSTNAME:-}
KUBECTL_CERTIFICATE=${KUBECTL_CERTIFICATE:-}

# Access to the kubernetes cluster when no kubeconfig was provided. This is
# through a token, or a username/password pair.
KUBECTL_TOKEN=${KUBECTL_TOKEN:-}
KUBECTL_USERNAME=${KUBECTL_USERNAME:-}
KUBECTL_PASSWORD=${KUBECTL_PASSWORD:-}

# Location of the kubectl binary, will be looked up in the PATH
KUBECTL_BINARY=${KUBECTL_BINARY:-"kubectl"}

# This uses the comments behind the options to show the help. Not extremly
# correct, but effective and simple.
usage() {
  echo "$0 installs kubectl auth context and runs kubectl with all remaining args:" && \
    grep "[[:space:]].)\ #" "$0" |
    sed 's/#//' |
    sed -r 's/([a-z])\)/-\1/'
  exit "${1:-0}"
}

while getopts "k:s:c:t:u:p:6b:vh-" opt; do
  case "$opt" in
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
    v) # Turn on verbosity
      KUBECTL_VERBOSE=1;;
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

# Does the value passed as a parameter contain only characters used in base64
# encoding.
_base64encoded() {
  test -z "$(printf %s\\n "$1" | tr -d '[A-Za-z0-9/=\n')"
}

# base64-decode value passed as first parameter on demand. When base64 decoding
# was forced in, no tests will be performed. Otherwise, an educated guess will
# be made, based on the content of the value. When base64 or inlining is
# required, the second argument contains the relative path to the file to
# created under the temporary directory.
_decode() {
  if [ "$KUBECTL_BASE64" = "1" ]; then
    _verbose "base64 decoding to ${TMPD}/${2}"
    printf %s\\n "$1" | base64 -d > "${TMPD}/${2}"
    chmod og-rw "${TMPD}/${2}"
    printf %s\\n "${TMPD}/${2}"
  elif [ -f "$1" ]; then
    _verbose "using file at $1"
    printf %s\\n "$1"
  elif _base64encoded "$1"; then
    _verbose "base64 decoding to ${TMPD}/${2}"
    printf %s\\n "$1" | base64 -d > "${TMPD}/${2}"
    chmod og-rw "${TMPD}/${2}"
    printf %s\\n "${TMPD}/${2}"
  else
    _verbose "inlining to ${TMPD}/${2}"
    printf %s\\n "$1" > "${TMPD}/${2}"
    chmod og-rw "${TMPD}/${2}"
    printf %s\\n "${TMPD}/${2}"
  fi
}

# Temporary directory for file storage, will be removed upon completion of the
# kubectl command.
TMPD=$(mktemp -d kubectl-XXXXXX)

# Transform options and remaining arguments into the positional argument list
# (we are in POSIX shell: we have no arrays and a single postional list)
if [ -n "$KUBECTL_KUBECONFIG" ]; then
  _verbose "Using kubeconfig information for cluster access and auth"
  set -- \
    --kubeconfig "$(_decode "$KUBECTL_KUBECONFIG" kubeconfig.yml)" \
    "$@"
elif [ -z "$KUBECTL_HOSTNAME" ] || [ -z "$KUBECTL_CERTIFICATE" ]; then
  _error "No cluster information provided"
elif [ -z "$KUBECTL_TOKEN" ]; then
  if [ -z "$KUBECTL_USERNAME" ] && [ -z "$KUBECTL_PASSWORD" ]; then
    _error "No user auth provided"
  else
    _verbose "Using token for cluster access and auth"
    set -- \
      --server "https://${KUBECTL_HOSTNAME}" \
      --certificate "$(_decode "$KUBECTL_CERTIFICATE" ca.crt)" \
      --username "$KUBECTL_USERNAME" \
      --password "$KUBECTL_PASSWORD" \
      "$@"
  fi
else
    _verbose "Using username/password for cluster access and auth"
    set -- \
      --server "https://${KUBECTL_HOSTNAME}" \
      --certificate "$(_decode "$KUBECTL_CERTIFICATE" ca.crt)" \
      --token "$KUBECTL_TOKEN" \
      "$@"
fi

# All arguments from incoming options/environment variables have been inserted,
# let's call kubectl with all of them
"$KUBECTL_BINARY" "$@"

# Cleanup. We should really trap. But the action guarantees that the directory
# content will be removed, by construction.
rm -rf "$TMPD"
