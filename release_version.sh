#!/usr/bin/env bash
# Resolve the version of the next release, and the upstream VS Code refs it is
# built from, without cloning the (large) `vscode` repository.
#
# It uses the same scheme as `get_repo.sh`: the upstream tag followed by the
# number of hours elapsed in the current year, e.g. `1.135.06042`. An existing
# RELEASE_VERSION is kept as-is, but has to extend the upstream tag, otherwise
# `get_repo.sh` would later refuse it.

set -e

VSCODE_QUALITY="${VSCODE_QUALITY:-stable}"

MS_TAG=$( jq -r '.tag' "./upstream/${VSCODE_QUALITY}.json" )
MS_COMMIT=$( jq -r '.commit' "./upstream/${VSCODE_QUALITY}.json" )

if [[ -z "${RELEASE_VERSION}" ]]; then
  TIME_PATCH=$( printf "%04d" $(($(date +%-j) * 24 + $(date +%-H))) )

  if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
    RELEASE_VERSION="${MS_TAG}${TIME_PATCH}-insider"
  else
    RELEASE_VERSION="${MS_TAG}${TIME_PATCH}"
  fi
fi

if [[ ! "${RELEASE_VERSION}" =~ ^${MS_TAG//./\\.}[0-9]+(-insider)?$ ]]; then
  echo "Error: RELEASE_VERSION '${RELEASE_VERSION}' doesn't extend the upstream tag '${MS_TAG}'" >&2
  echo "Expected something like '${MS_TAG}1234'." >&2
  exit 1
fi

echo "MS_TAG=\"${MS_TAG}\""
echo "MS_COMMIT=\"${MS_COMMIT}\""
echo "RELEASE_VERSION=\"${RELEASE_VERSION}\""

# for GH actions
if [[ "${GITHUB_ENV}" ]]; then
  {
    echo "MS_TAG=${MS_TAG}"
    echo "MS_COMMIT=${MS_COMMIT}"
    echo "RELEASE_VERSION=${RELEASE_VERSION}"
  } >> "${GITHUB_ENV}"
fi

export MS_TAG
export MS_COMMIT
export RELEASE_VERSION
