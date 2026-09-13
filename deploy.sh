#!/usr/bin/env bash
# Build, package, and install the Rush-branded Linux IDE.

set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

export APP_NAME="${APP_NAME:-Rush}"
export BINARY_NAME="${BINARY_NAME:-rush}"
export ASSETS_REPOSITORY="${ASSETS_REPOSITORY:-rush-automations/rush}"
export GH_REPO_PATH="${GH_REPO_PATH:-rush-automations/rush}"
export ORG_NAME="${ORG_NAME:-Rush Automations}"
export OS_NAME="${OS_NAME:-linux}"
export VSCODE_QUALITY="${VSCODE_QUALITY:-stable}"
export RELEASE_VERSION="${RELEASE_VERSION:-local}"

install_system_dependencies() {
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo is required for automatic system dependency installation." >&2
    return 1
  fi

  # Cache sudo credentials once, then wait for Ubuntu's unattended upgrades
  # instead of racing dpkg or telling users to remove its lock file.
  if ! sudo -v; then
    echo "Could not authenticate with sudo in this shell." >&2
    echo "Run ./deploy.sh from an interactive terminal and enter your password when prompted." >&2
    return 1
  fi
  if command -v fuser >/dev/null 2>&1; then
    local attempt
    for attempt in {1..60}; do
      if ! sudo -n fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock >/dev/null 2>&1; then
        break
      fi
      echo "Waiting for the system package manager to finish (attempt ${attempt}/60)..."
      sleep 5
    done
    if sudo -n fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock >/dev/null 2>&1; then
      echo "The system package manager is still busy after five minutes." >&2
      echo "Please wait for unattended upgrades to finish, then run ./deploy.sh again." >&2
      return 1
    fi
  fi

  if command -v apt-get >/dev/null 2>&1; then
    # A broken third-party source (for example GitHub CLI) should not prevent
    # apt from installing a package available from the Ubuntu repositories.
    sudo apt-get update || echo "Warning: one or more apt sources failed to update; continuing."
    sudo apt-get install -y libkrb5-dev libx11-dev libxkbfile-dev
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y krb5-devel libX11-devel libxkbfile-devel
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm krb5 libx11 libxkbfile
  else
    echo "Could not identify a supported Linux package manager." >&2
    return 1
  fi
}

check_build_prerequisites() {
  local required_node=""
  local current_node=""

  if [[ -f "${ROOT_DIR}/.nvmrc" ]]; then
    required_node="$(tr -d '[:space:]' < "${ROOT_DIR}/.nvmrc")"
    current_node="$(node --version 2>/dev/null | sed 's/^v//' || true)"

    if [[ "${current_node}" != "${required_node}" ]]; then
      NVM_SCRIPT="${NVM_DIR:-${HOME}/.config/nvm}/nvm.sh"
      if ! type nvm >/dev/null 2>&1 && [[ -s "${NVM_SCRIPT}" ]]; then
        # shellcheck disable=SC1091
        source "${NVM_SCRIPT}"
      fi
      if type nvm >/dev/null 2>&1; then
        echo "Switching Node.js from ${current_node:-unknown} to ${required_node}..."
        if ! nvm use "${required_node}" >/dev/null 2>&1; then
          echo "Node ${required_node} is not installed; installing it with NVM..."
          nvm install "${required_node}" >/dev/null
          nvm use "${required_node}" >/dev/null
        fi
      else
        echo "Rush requires Node.js ${required_node}; found ${current_node:-unknown}." >&2
        echo "Install/use it with: nvm install ${required_node} && nvm use ${required_node}" >&2
        exit 1
      fi
    fi
  fi

  if [[ ! -f /usr/include/gssapi/gssapi.h ]] || ! command -v krb5-config >/dev/null 2>&1 || \
    ! command -v pkg-config >/dev/null 2>&1 || ! pkg-config --exists x11 xkbfile; then
    echo "Installing Linux native build dependencies..."
    install_system_dependencies || exit 1
  fi

  if [[ ! -f /usr/include/gssapi/gssapi.h ]] || ! command -v krb5-config >/dev/null 2>&1 || \
    ! command -v pkg-config >/dev/null 2>&1 || ! pkg-config --exists x11 xkbfile; then
    echo "Rush is missing required Linux native build dependencies (Kerberos/GSSAPI, X11, or xkbfile)." >&2
    if command -v apt-get >/dev/null 2>&1; then
      echo "Install them with: sudo apt-get update && sudo apt-get install -y libkrb5-dev libx11-dev libxkbfile-dev" >&2
    elif command -v dnf >/dev/null 2>&1; then
      echo "Install them with: sudo dnf install krb5-devel" >&2
    elif command -v pacman >/dev/null 2>&1; then
      echo "Install them with: sudo pacman -S krb5" >&2
    fi
    exit 1
  fi
}

if [[ $# -gt 0 ]]; then
  echo "deploy.sh takes no flags; run it as: ./deploy.sh" >&2
  exit 2
fi

if [[ "${OS_NAME}" != "linux" ]]; then
  echo "deploy.sh currently creates local Linux packages only (OS_NAME=${OS_NAME})." >&2
  exit 2
fi

case "$(uname -m)" in
  x86_64) HOST_ARCH="x64" ;;
  aarch64|arm64) HOST_ARCH="arm64" ;;
  *) HOST_ARCH="${VSCODE_ARCH}" ;;
esac
export VSCODE_ARCH="${VSCODE_ARCH:-${HOST_ARCH}}"

BUNDLE_DIR="${ROOT_DIR}/VSCode-linux-${VSCODE_ARCH}"
DIST_DIR="${ROOT_DIR}/dist"
VERSION_LABEL="${RELEASE_VERSION%-insider}"
TARBALL="${DIST_DIR}/Rush-${VERSION_LABEL}-linux-${VSCODE_ARCH}.tar.gz"

if [[ ! -d "${BUNDLE_DIR}" ]]; then
  check_build_prerequisites
  if [[ ! -d "${ROOT_DIR}/vscode" ]]; then
    echo "Preparing the upstream editor source..."
    # get_repo.sh resolves the current stable/insider version and exports the
    # matching MS_TAG, MS_COMMIT, and RELEASE_VERSION for build.sh.
    unset RELEASE_VERSION
    # shellcheck disable=SC1091
    source ./get_repo.sh
    VERSION_LABEL="${RELEASE_VERSION%-insider}"
    TARBALL="${DIST_DIR}/Rush-${VERSION_LABEL}-linux-${VSCODE_ARCH}.tar.gz"
  fi
  echo "No Linux bundle found. Building Rush for ${VSCODE_ARCH}..."
  export SHOULD_BUILD="yes"
  export CI_BUILD="no"
  export SHOULD_BUILD_REH="no"
  export SHOULD_BUILD_REH_WEB="no"
  export SHOULD_BUILD_CLI="no"
  export SHOULD_BUILD_DEB="no"
  export SHOULD_BUILD_RPM="no"
  export SHOULD_BUILD_TAR="no"
  ./build.sh
fi

if [[ ! -d "${BUNDLE_DIR}" ]]; then
  echo "Linux bundle not found: ${BUNDLE_DIR}" >&2
  echo "The Linux build did not produce the expected bundle: ${BUNDLE_DIR}" >&2
  exit 1
fi

mkdir -p "${DIST_DIR}"
chmod +x "${BUNDLE_DIR}/${BINARY_NAME}" 2>/dev/null || true
chmod +x "${BUNDLE_DIR}/bin/${BINARY_NAME}" 2>/dev/null || true

echo "Creating portable Rush package..."
tar -czf "${TARBALL}" -C "${BUNDLE_DIR}" .

APPIMAGE=""
if command -v appimagetool >/dev/null 2>&1; then
  APPDIR="${DIST_DIR}/Rush.AppDir"
  rm -rf "${APPDIR}"
  mkdir -p "${APPDIR}"
  cp -a "${BUNDLE_DIR}/." "${APPDIR}/"
  cp icons/rush.svg "${APPDIR}/rush.svg"
  sed -e 's#@@NAME_LONG@@#Rush#g' \
      -e 's#@@NAME_SHORT@@#Rush#g' \
      -e 's#@@NAME@@#rush#g' \
      -e 's#@@EXEC@@#rush#g' \
      -e 's#@@ICON@@#rush#g' \
      -e 's#@@URLPROTOCOL@@#rush#g' \
      src/stable/resources/linux/code.desktop > "${APPDIR}/rush.desktop"
  # An AppImage runs from a user-owned mountpoint, so its copy of the SUID
  # helper can never be root-owned; drop it and let Chromium pick the
  # user-namespace sandbox instead of aborting on a misconfigured helper.
  rm -f "${APPDIR}/chrome-sandbox"
  appimagetool "${APPDIR}" "${DIST_DIR}/Rush-${VERSION_LABEL}-linux-${VSCODE_ARCH}.AppImage"
  APPIMAGE="${DIST_DIR}/Rush-${VERSION_LABEL}-linux-${VSCODE_ARCH}.AppImage"
  chmod +x "${APPIMAGE}"
else
  echo "appimagetool not found; created a portable tarball instead."
fi

INSTALL_ROOT="${RUSH_INSTALL_ROOT:-${HOME}/.local/opt}"
INSTALL_DIR="${INSTALL_ROOT}/rush-${VERSION_LABEL}"
ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"
BIN_DIR="${HOME}/.local/bin"
APPLICATIONS_DIR="${HOME}/.local/share/applications"

# Replace any previous install so removed files from an older build cannot
# linger next to the new ones. A root-owned chrome-sandbox from an earlier run
# needs sudo to clear.
if [[ -d "${INSTALL_DIR}" ]]; then
  rm -rf "${INSTALL_DIR}" 2>/dev/null || sudo rm -rf "${INSTALL_DIR}"
fi
mkdir -p "${INSTALL_DIR}" "${BIN_DIR}" "${APPLICATIONS_DIR}" "${ICON_DIR}"
tar -xzf "${TARBALL}" -C "${INSTALL_DIR}"
cp icons/rush.svg "${ICON_DIR}/rush.svg"

if [[ -x "${INSTALL_DIR}/${BINARY_NAME}" ]]; then
  EXECUTABLE="${INSTALL_DIR}/${BINARY_NAME}"
elif [[ -x "${INSTALL_DIR}/code" ]]; then
  EXECUTABLE="${INSTALL_DIR}/code"
else
  echo "Could not find the Rush executable in ${INSTALL_DIR}" >&2
  exit 1
fi

# Chromium refuses to start when its SUID helper is present but not owned by
# root with mode 4755, and tar drops the setuid bit on extraction as a normal
# user. Ubuntu 24.04+ also blocks the unprivileged user-namespace sandbox that
# Chromium would otherwise fall back to, so fix the helper up front.
SANDBOX_BINARY="${INSTALL_DIR}/chrome-sandbox"
SANDBOX_MODE="suid"
LAUNCH_FLAGS=""

sandbox_helper_is_ready() {
  [[ -e "${SANDBOX_BINARY}" ]] && [[ "$(stat -c '%u:%a' "${SANDBOX_BINARY}")" == "0:4755" ]]
}

user_namespaces_available() {
  unshare --user --map-root-user true >/dev/null 2>&1
}

if [[ -e "${SANDBOX_BINARY}" ]] && ! sandbox_helper_is_ready; then
  echo "Configuring the Chromium sandbox helper (needs sudo)..."
  if sudo -v && sudo chown root:root "${SANDBOX_BINARY}" && sudo chmod 4755 "${SANDBOX_BINARY}"; then
    echo "  chrome-sandbox is now root-owned with mode 4755."
  elif user_namespaces_available; then
    # Without the SUID helper Chromium uses the user-namespace sandbox, but
    # only if the helper is absent rather than misconfigured.
    mv "${SANDBOX_BINARY}" "${SANDBOX_BINARY}.disabled"
    SANDBOX_MODE="userns"
    echo "  Could not use sudo; falling back to the user-namespace sandbox." >&2
  else
    mv "${SANDBOX_BINARY}" "${SANDBOX_BINARY}.disabled"
    SANDBOX_MODE="disabled"
    LAUNCH_FLAGS="--no-sandbox"
    echo "  Could not use sudo and user namespaces are restricted on this kernel." >&2
    echo "  Rush will launch with --no-sandbox (reduced process isolation)." >&2
    echo "  Re-run ./deploy.sh from an interactive terminal to restore the sandbox." >&2
  fi
fi

if [[ -x "${INSTALL_DIR}/bin/${BINARY_NAME}" ]]; then
  CLI_TARGET="${INSTALL_DIR}/bin/${BINARY_NAME}"
else
  CLI_TARGET="${EXECUTABLE}"
fi

# A wrapper rather than a symlink, so the launch flags chosen above apply to
# the CLI as well as the desktop launcher.
CLI_COMMAND="${BIN_DIR}/${BINARY_NAME}"
rm -f "${CLI_COMMAND}"
cat > "${CLI_COMMAND}" <<EOF
#!/usr/bin/env sh
# Generated by deploy.sh - do not edit; re-run ./deploy.sh instead.
exec "${CLI_TARGET}" ${LAUNCH_FLAGS} "\$@"
EOF
chmod +x "${CLI_COMMAND}"

sed -e 's#@@NAME_LONG@@#Rush#g' \
    -e 's#@@NAME_SHORT@@#Rush#g' \
    -e 's#@@NAME@@#rush#g' \
    -e "s#@@EXEC@@#${EXECUTABLE}${LAUNCH_FLAGS:+ ${LAUNCH_FLAGS}}#g" \
    -e 's#@@ICON@@#rush#g' \
    -e 's#@@URLPROTOCOL@@#rush#g' \
    src/stable/resources/linux/code.desktop > "${APPLICATIONS_DIR}/rush.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${APPLICATIONS_DIR}" >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor" >/dev/null 2>&1 || true
fi

echo
echo "Rush installed successfully."
echo "  App directory: ${INSTALL_DIR}"
echo "  CLI command:   ${CLI_COMMAND}"
echo "  App launcher:  ${APPLICATIONS_DIR}/rush.desktop"
case "${SANDBOX_MODE}" in
  suid)     echo "  Sandbox:       SUID helper (chrome-sandbox, root:root 4755)" ;;
  userns)   echo "  Sandbox:       user namespaces (SUID helper disabled)" ;;
  disabled) echo "  Sandbox:       DISABLED (--no-sandbox)" ;;
esac
echo "  Run now:       ${CLI_COMMAND}"

case ":${PATH}:" in
  *":${BIN_DIR}:"*) ;;
  *)
    echo
    echo "Note: ${BIN_DIR} is not on your PATH; add it to use \`${BINARY_NAME}\` directly."
    ;;
esac

echo
echo "Package: ${TARBALL}"
[[ -n "${APPIMAGE}" ]] && echo "AppImage: ${APPIMAGE}"
exit 0
