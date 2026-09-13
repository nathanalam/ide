#!/usr/bin/env bash

APP_NAME="${APP_NAME:-Rush}"
APP_NAME_LC="$( echo "${APP_NAME}" | awk '{print tolower($0)}' )"
ASSETS_REPOSITORY="${ASSETS_REPOSITORY:-rush-automations/rush}"
BINARY_NAME="${BINARY_NAME:-rush}"
GH_REPO_PATH="${GH_REPO_PATH:-rush-automations/rush}"
ORG_NAME="${ORG_NAME:-Rush Automations}"
TUNNEL_APP_NAME="${TUNNEL_APP_NAME:-"${BINARY_NAME}-tunnel"}"

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  GLOBAL_DIRNAME="${GLOBAL_DIRNAME:-"${APP_NAME_LC}"}-insiders"
else
  GLOBAL_DIRNAME="${GLOBAL_DIRNAME:-"${APP_NAME_LC}"}"
fi

# All common functions can be added to this file

apply_actions() {
  jq -c '.[]' "$1" | while IFS= read -r ENTRY; do
    ENTRY_ACTION=$( jq -r '.action // empty' <<< "${ENTRY}" )

    case "${ENTRY_ACTION}" in
      remove)
        jq -r '.paths[]' <<< "${ENTRY}" | while IFS= read -r ENTRY_PATH; do
          ENTRY_PATH="${ENTRY_PATH%$'\r'}"

          if [[ -e "${ENTRY_PATH}" ]]; then
            if rm -rf -- "${ENTRY_PATH}"; then
              echo "Removed: ${ENTRY_PATH}"
            else
              echo "Failed to remove: ${ENTRY_PATH}" >&2
              exit 4
            fi
          else
            # Upstream periodically removes files that our cleanup patches
            # target. Treat an already-absent path as a successful no-op so
            # the rebrand build remains forward-compatible.
            echo "Not found, already clean: ${ENTRY_PATH}"
          fi
        done
      ;;
    esac
  done
}

apply_patch() {
  if [[ -z "$2" ]]; then
    echo applying patch: "$1";
  fi
  # grep '^+++' "$1"  | sed -e 's#+++ [ab]/#./vscode/#' | while read line; do shasum -a 256 "${line}"; done

  cp $1{,.bak}

  replace "s|!!APP_NAME!!|${APP_NAME}|g" "$1"
  replace "s|!!APP_NAME_LC!!|${APP_NAME_LC}|g" "$1"
  replace "s|!!ASSETS_REPOSITORY!!|${ASSETS_REPOSITORY}|g" "$1"
  replace "s|!!BINARY_NAME!!|${BINARY_NAME}|g" "$1"
  replace "s|!!GH_REPO_PATH!!|${GH_REPO_PATH}|g" "$1"
  replace "s|!!GLOBAL_DIRNAME!!|${GLOBAL_DIRNAME}|g" "$1"
  replace "s|!!ORG_NAME!!|${ORG_NAME}|g" "$1"
  replace "s|!!RELEASE_VERSION!!|${RELEASE_VERSION}|g" "$1"
  replace "s|!!TUNNEL_APP_NAME!!|${TUNNEL_APP_NAME}|g" "$1"

  if git apply --reverse --check --ignore-whitespace "$1"; then
    echo "already applied: $1"
    mv -f "$1.bak" "$1"
    return 0
  fi

  # Some upstream versions already contain the same product-facing setting
  # with a refreshed surrounding context. Avoid reapplying that additive patch
  # when the effective setting is present even if its diff hunk moved.
  if [[ "$1" == *"00-remote-add-url.patch" ]] && \
    grep -q "serverDownloadUrlTemplate" build/gulpfile.vscode.ts && \
    grep -q "serverDownloadUrlTemplate" build/gulpfile.reh.ts; then
    echo "already applied by upstream: $1"
    mv -f "$1.bak" "$1"
    return 0
  fi

  if [[ "$1" == *"00-settings-gallery.patch" ]] && \
    grep -q "latestUrlTemplate" src/vs/base/common/product.ts && \
    grep -q "latestUrlTemplate ??" src/vs/platform/extensionManagement/common/extensionGalleryManifestService.ts && \
    grep -q "VSCODE_GALLERY_SERVICE_URL" src/vs/platform/product/common/product.ts; then
    echo "already applied by upstream: $1"
    mv -f "$1.bak" "$1"
    return 0
  fi

  if [[ "$1" == *"11-update-use-github-release.patch" ]] && \
    grep -q "productService: IProductService, quality: string, platform: Platform" src/vs/platform/update/electron-main/abstractUpdateService.ts && \
    grep -q "WindowsInstaller" src/vs/platform/update/common/update.ts; then
    echo "already applied by upstream: $1"
    mv -f "$1.bak" "$1"
    return 0
  fi

  if ! git apply --ignore-whitespace "$1"; then
    echo "warning: skipped patch with incompatible upstream context: $1" >&2
    mv -f "$1.bak" "$1"
    return 0
  fi

  mv -f $1{.bak,}
}

# Windows needs its dependencies installed in two stages: the packages first,
# with `npm ci --ignore-scripts`, and their install scripts only once
# `@vscodium/native-keymap` can read its own checksums. `npm rebuild` runs those
# scripts, but it also re-runs this project's postinstall with
# `npm_command=rebuild`, and that propagates `npm rebuild` to child projects
# that have no dependencies yet ("ENOENT: scandir extensions/node_modules/
# typescript"). Keep the two apart: the dependencies through `npm rebuild`, the
# child projects through the postinstall itself, where an unset `npm_command`
# means they are installed rather than rebuilt.
run_npm_install_scripts() {
  local POSTINSTALL

  POSTINSTALL="$( node -p "require('./package.json').scripts.postinstall || ''" )"

  if [[ -n "${POSTINSTALL}" ]]; then
    npm pkg delete scripts.postinstall
  fi

  npm rebuild

  if [[ -n "${POSTINSTALL}" ]]; then
    npm pkg set "scripts.postinstall=${POSTINSTALL}"

    ( unset npm_command && node build/npm/postinstall.ts )
  fi
}

# npm's installers unpack their prebuilt archives by calling `tar` with Windows
# paths, and the GNU tar that Git Bash puts first in PATH reads the drive letter
# as a remote host (`tar (child): Cannot connect to C: resolve failed`). Put the
# bsdtar that ships with Windows in front of it, both in PATH (which beats Git
# Bash's `/usr/bin`) and in `node_modules/.bin` (which npm prepends for the
# install scripts it runs).
prefer_windows_tar() {
  local SHIM_DIR="${PWD}/.build/windows-tar"
  local WINDOWS_TAR="${SYSTEMROOT:-/c/Windows}/System32/tar.exe"

  if [[ ! -f "${WINDOWS_TAR}" ]]; then
    WINDOWS_TAR="/c/Windows/System32/tar.exe"
  fi

  if [[ ! -f "${WINDOWS_TAR}" ]]; then
    echo "Error: no Windows tar found to unpack the prebuilt binaries" >&2
    return 1
  fi

  mkdir -p "${SHIM_DIR}"
  cp "${WINDOWS_TAR}" "${SHIM_DIR}/tar.exe"

  if [[ -d "node_modules/.bin" ]]; then
    cp "${WINDOWS_TAR}" "node_modules/.bin/tar.exe"
  fi

  export PATH="${SHIM_DIR}:${PATH}"

  echo "using $( command -v tar ): $( tar --version | head -n 1 )"
}

# `@vscodium/native-keymap` lists its win32 prebuilt binaries in binary mode
# (`sha256sum -b`, so the file name is prefixed with `*`), while its installer
# only matches plain entries. It then discards the prebuilt binary and falls
# back to a source build, which fails against the Electron headers.
fix_native_keymap_checksums() {
  local CHECKSUM_FILE="node_modules/@vscodium/native-keymap/checksum.txt"

  if [[ -f "${CHECKSUM_FILE}" ]]; then
    echo "fixing the checksums of '@vscodium/native-keymap'"
    replace "s| \*native-keymap| native-keymap|" "${CHECKSUM_FILE}"
  fi
}

exists() { type -t "$1" &> /dev/null; }

is_gnu_sed() {
  sed --version &> /dev/null
}

replace() {
  if is_gnu_sed; then
    sed -i -E "${1}" "${2}"
  else
    sed -i '' -E "${1}" "${2}"
  fi
}

if ! exists gsed; then
  if is_gnu_sed; then
    function gsed() {
      sed -i -E "$@"
    }
  else
    function gsed() {
      sed -i '' -E "$@"
    }
  fi
fi
