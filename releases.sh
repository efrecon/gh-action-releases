#!/bin/sh

# Shell sanity. Stop on errors and undefined variables.
set -eu

# This is a readlink -f implementation so this script can (perhaps) run on MacOS
abspath() {
  is_abspath() {
    case "$1" in
      /* | ~*) true;;
      *) false;;
    esac
  }

  if [ -d "$1" ]; then
    ( cd -P -- "$1" && pwd -P )
  elif [ -L "$1" ]; then
    if is_abspath "$(readlink "$1")"; then
      abspath "$(readlink "$1")"
    else
      abspath "$(dirname "$1")/$(readlink "$1")"
    fi
  else
    printf %s\\n "$(abspath "$(dirname "$1")")/$(basename "$1")"
  fi
}

# Resolve the root directory hosting this script to an absolute path, symbolic
# links resolved.
ROOTDIR=$( cd -P -- "$(dirname -- "$(command -v -- "$(abspath "$0")")")" && pwd -P )

# shellcheck source=contrib/reg-tags/image_api.sh
. "$ROOTDIR/contrib/reg-tags/image_api.sh"

: "${RELEASES_PROJECT:=}"

: "${RELEASES_MINVER:=}"

: "${RELEASES_REGEX:="^v?[0-9]+\\.[0-9]+\\.[0-9]+"}"

: "${RELEASES_SEPARATOR:=","}"

: "${GITHUB_OUTPUT:="/dev/stdout"}"

releases() {
  # Ask GH for the list of releases matching the tag pattern, then fool the sort
  # -V option to properly understand semantic versioning. Arrange for latest
  # version to be at the top. See: https://stackoverflow.com/a/40391207
  github_releases -r "$RELEASES_REGEX" -- "$1" |
    sed '/-/!{s/$/_/}' |
    sort -Vr |
    sed 's/_$//'
}

latest=
printf "releases=" >> "$GITHUB_OUTPUT"
for tag in $(releases "$RELEASES_PROJECT"); do
  if [ -n "$RELEASES_MINVER" ]; then
    if [ "$(img_version "${tag#v}")" -ge "$(img_version "$RELEASES_MINVER")" ]; then
      if [ -z "$latest" ]; then
        printf %s "$tag" >> "$GITHUB_OUTPUT"
      else
        printf %s%s "$RELEASES_SEPARATOR" "$tag" >> "$GITHUB_OUTPUT"
      fi
    fi
  else
    if [ -z "$latest" ]; then
      printf %s "$tag" >> "$GITHUB_OUTPUT"
    else
      printf %s%s "$RELEASES_SEPARATOR" "$tag" >> "$GITHUB_OUTPUT"
    fi
  fi

  if [ -z "$latest" ]; then
    latest=$tag
  fi
done
printf "\n" >> "$GITHUB_OUTPUT"

[ -n "$latest" ] && printf "latest=%s\n" "$latest" >> "$GITHUB_OUTPUT"
