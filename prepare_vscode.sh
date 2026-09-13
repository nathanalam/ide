#!/usr/bin/env bash
# shellcheck disable=SC1091,2154

set -e

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  cp -rp src/insider/* vscode/
else
  cp -rp src/stable/* vscode/
fi

cp -f LICENSE vscode/LICENSE.txt

cd vscode || { echo "'vscode' dir not found"; exit 1; }

{ set +x; } 2>/dev/null

# {{{ product.json
cp product.json{,.bak}

setpath() {
  local jsonTmp
  { set +x; } 2>/dev/null
  jsonTmp=$( jq --arg 'value' "${3}" "setpath(path(.${2}); \$value)" "${1}.json" )
  echo "${jsonTmp}" > "${1}.json"
  set -x
}

setpath_json() {
  local jsonTmp
  { set +x; } 2>/dev/null
  jsonTmp=$( jq --argjson 'value' "${3}" "setpath(path(.${2}); \$value)" "${1}.json" )
  echo "${jsonTmp}" > "${1}.json"
  set -x
}

setpath "product" "checksumFailMoreInfoUrl" "https://go.microsoft.com/fwlink/?LinkId=828886"
setpath "product" "documentationUrl" "https://go.microsoft.com/fwlink/?LinkID=533484#vscode"
setpath_json "product" "extensionsGallery" '{"serviceUrl": "https://open-vsx.org/vscode/gallery", "itemUrl": "https://open-vsx.org/vscode/item", "latestUrlTemplate": "https://open-vsx.org/vscode/gallery/{publisher}/{name}/latest", "controlUrl": "https://raw.githubusercontent.com/EclipseFdn/publish-extensions/refs/heads/master/extension-control/extensions.json"}'

setpath "product" "introductoryVideosUrl" "https://go.microsoft.com/fwlink/?linkid=832146"
setpath "product" "keyboardShortcutsUrlLinux" "https://go.microsoft.com/fwlink/?linkid=832144"
setpath "product" "keyboardShortcutsUrlMac" "https://go.microsoft.com/fwlink/?linkid=832143"
setpath "product" "keyboardShortcutsUrlWin" "https://go.microsoft.com/fwlink/?linkid=832145"
setpath "product" "licenseUrl" "https://github.com/VSCodium/vscodium/blob/master/LICENSE"
setpath_json "product" "linkProtectionTrustedDomains" '["https://open-vsx.org"]'
setpath "product" "releaseNotesUrl" "https://go.microsoft.com/fwlink/?LinkID=533483#vscode"
setpath "product" "reportIssueUrl" "https://github.com/VSCodium/vscodium/issues/new"
setpath "product" "requestFeatureUrl" "https://go.microsoft.com/fwlink/?LinkID=533482"
setpath "product" "tipsAndTricksUrl" "https://go.microsoft.com/fwlink/?linkid=852118"
setpath "product" "twitterUrl" "https://go.microsoft.com/fwlink/?LinkID=533687"

if [[ "${DISABLE_UPDATE}" != "yes" ]]; then
  setpath "product" "updateUrl" "https://raw.githubusercontent.com/VSCodium/versions/refs/heads/master"

  if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
    setpath "product" "downloadUrl" "https://github.com/VSCodium/vscodium-insiders/releases"
  else
    setpath "product" "downloadUrl" "https://github.com/VSCodium/vscodium/releases"
  fi

  # if [[ "${OS_NAME}" == "windows" ]]; then
  #   setpath_json "product" "win32VersionedUpdate" "true"
  # fi
fi

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  setpath "product" "nameShort" "Rush - Insiders"
  setpath "product" "nameLong" "Rush - Insiders"
  setpath "product" "applicationName" "rush-insiders"
  setpath "product" "dataFolderName" ".rush-insiders"
  setpath "product" "linuxIconName" "rush-insiders"
  setpath "product" "quality" "insider"
  setpath "product" "urlProtocol" "rush-insiders"
  setpath "product" "serverApplicationName" "rush-server-insiders"
  setpath "product" "serverDataFolderName" ".rush-server-insiders"
  setpath "product" "darwinBundleIdentifier" "com.rushautomations.RushInsiders"
  setpath "product" "win32AppUserModelId" "RushAutomations.RushInsiders"
  setpath "product" "win32DirName" "Rush Insiders"
  setpath "product" "win32MutexName" "rushinsiders"
  setpath "product" "win32NameVersion" "Rush Insiders"
  setpath "product" "win32RegValueName" "RushInsiders"
  setpath "product" "win32ShellNameShort" "Rush Insiders"
  setpath "product" "win32AppId" "{{EF35BB36-FA7E-4BB9-B7DA-D1E09F2DA9C9}"
  setpath "product" "win32x64AppId" "{{B2E0DDB2-120E-4D34-9F7E-8C688FF839A2}"
  setpath "product" "win32arm64AppId" "{{44721278-64C6-4513-BC45-D48E07830599}"
  setpath "product" "win32UserAppId" "{{ED2E5618-3E7E-4888-BF3C-A6CCC84F586F}"
  setpath "product" "win32x64UserAppId" "{{20F79D0D-A9AC-4220-9A81-CE675FFB6B41}"
  setpath "product" "win32arm64UserAppId" "{{2E362F92-14EA-455A-9ABD-3E656BBBFE71}"
  setpath "product" "tunnelApplicationName" "rush-insiders-tunnel"
  setpath "product" "win32TunnelServiceMutex" "rushinsiders-tunnelservice"
  setpath "product" "win32TunnelMutex" "rushinsiders-tunnel"
  setpath "product" "win32ContextMenu.x64.clsid" "90AAD229-85FD-43A3-B82D-8598A88829CF"
  setpath "product" "win32ContextMenu.arm64.clsid" "7544C31C-BDBF-4DDF-B15E-F73A46D6723D"
else
  setpath "product" "nameShort" "Rush"
  setpath "product" "nameLong" "Rush"
  setpath "product" "applicationName" "rush"
  setpath "product" "linuxIconName" "rush"
  setpath "product" "quality" "stable"
  setpath "product" "urlProtocol" "rush"
  setpath "product" "serverApplicationName" "rush-server"
  setpath "product" "serverDataFolderName" ".rush-server"
  setpath "product" "darwinBundleIdentifier" "com.rushautomations.Rush"
  setpath "product" "win32AppUserModelId" "RushAutomations.Rush"
  setpath "product" "win32DirName" "Rush"
  setpath "product" "win32MutexName" "rush"
  setpath "product" "win32NameVersion" "Rush"
  setpath "product" "win32RegValueName" "Rush"
  setpath "product" "win32ShellNameShort" "Rush"
  setpath "product" "win32AppId" "{{763CBF88-25C6-4B10-952F-326AE657F16B}"
  setpath "product" "win32x64AppId" "{{88DA3577-054F-4CA1-8122-7D820494CFFB}"
  setpath "product" "win32arm64AppId" "{{67DEE444-3D04-4258-B92A-BC1F0FF2CAE4}"
  setpath "product" "win32UserAppId" "{{0FD05EB4-651E-4E78-A062-515204B47A3A}"
  setpath "product" "win32x64UserAppId" "{{2E1F05D1-C245-4562-81EE-28188DB6FD17}"
  setpath "product" "win32arm64UserAppId" "{{57FD70A5-1B8D-4875-9F40-C5553F094828}"
  setpath "product" "tunnelApplicationName" "rush-tunnel"
  setpath "product" "win32TunnelServiceMutex" "rush-tunnelservice"
  setpath "product" "win32TunnelMutex" "rush-tunnel"
  setpath "product" "win32ContextMenu.x64.clsid" "D910D5E6-B277-4F4A-BDC5-759A34EEE25D"
  setpath "product" "win32ContextMenu.arm64.clsid" "4852FC55-4A84-4EA1-9C86-D53BE3DF83C0"
fi

setpath_json "product" "tunnelApplicationConfig" '{}'

jsonTmp=$( jq -s '.[0] * .[1]' product.json ../product.json )
echo "${jsonTmp}" > product.json && unset jsonTmp

cat product.json
# }}}

# include common functions
. ../utils.sh

# {{{ apply patches

echo "APP_NAME=\"${APP_NAME}\""
echo "APP_NAME_LC=\"${APP_NAME_LC}\""
echo "ASSETS_REPOSITORY=\"${ASSETS_REPOSITORY}\""
echo "BINARY_NAME=\"${BINARY_NAME}\""
echo "GH_REPO_PATH=\"${GH_REPO_PATH}\""
echo "GLOBAL_DIRNAME=\"${GLOBAL_DIRNAME}\""
echo "ORG_NAME=\"${ORG_NAME}\""
echo "TUNNEL_APP_NAME=\"${TUNNEL_APP_NAME}\""

if [[ "${DISABLE_UPDATE}" == "yes" ]]; then
  apply_patch ../patches/00-update-disable.patch.yet
fi

for file in ../patches/*.json; do
  if [[ -f "${file}" ]]; then
    apply_actions "${file}"
  fi
done

for file in ../patches/*.patch; do
  if [[ -f "${file}" ]]; then
    apply_patch "${file}"
  fi
done

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  for file in ../patches/insider/*.patch; do
    if [[ -f "${file}" ]]; then
      apply_patch "${file}"
    fi
  done
fi

if [[ -d "../patches/${OS_NAME}/" ]]; then
  for file in "../patches/${OS_NAME}/"*.patch; do
    if [[ -f "${file}" ]]; then
      apply_patch "${file}"
    fi
  done
fi

for file in ../patches/user/*.patch; do
  if [[ -f "${file}" ]]; then
    apply_patch "${file}"
  fi
done
# }}}

set -x

# {{{ install dependencies
export ELECTRON_SKIP_BINARY_DOWNLOAD=1
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

if [[ "${OS_NAME}" == "linux" ]]; then
  export VSCODE_SKIP_NODE_VERSION_CHECK=1

  if [[ "${npm_config_arch}" == "arm" ]]; then
    export npm_config_arm_version=7
  fi
elif [[ "${OS_NAME}" == "windows" ]]; then
  if [[ "${npm_config_arch}" == "arm" ]]; then
    export npm_config_arm_version=7
  fi
else
  if [[ "${CI_BUILD}" != "no" ]]; then
    clang++ --version
  fi
fi

node build/npm/preinstall.ts

mv .npmrc .npmrc.bak
cp ../npmrc .npmrc

# Keep the upstream Electron and Node build metadata while applying our
# repository-specific npm settings. These values change with every upstream
# release and are required by the packaging scripts.
for key in target ms_build_id runtime ignore-scripts; do
  value=$( sed -n "s/^${key}=//p" .npmrc.bak | head -n 1 )
  if [[ -n "${value}" ]]; then
    echo "${key}=${value}" >> .npmrc
  fi
done

# Prevent two local deploys from running npm ci against the same generated
# checkout at once. Concurrent npm cleanup is a common source of ENOENT and
# ENOTEMPTY failures in native modules.
if command -v flock >/dev/null 2>&1; then
  exec 9>"${TMPDIR:-/tmp}/rush-vscode-npm-${UID}.lock"
  flock 9
fi

# On Windows, `@vscodium/native-keymap` rejects its own prebuilt binary (see
# `fix_native_keymap_checksums`), so hold the install scripts back until its
# checksum manifest has been fixed.
NPM_CI_ARGS=()

if [[ "${OS_NAME}" == "windows" ]]; then
  NPM_CI_ARGS+=( "--ignore-scripts" )
fi

for i in {1..5}; do # try 5 times
  if [[ "${CI_BUILD}" != "no" && "${OS_NAME}" == "osx" ]]; then
    CXX=clang++ npm ci "${NPM_CI_ARGS[@]}" && break
  else
    npm ci "${NPM_CI_ARGS[@]}" && break
  fi

  if [[ $i == 5 ]]; then
    echo "Npm install failed too many times" >&2
    exit 1
  fi
  echo "Npm install failed $i, trying again..."

  sleep $(( 15 * (i + 1)))
done

if [[ "${OS_NAME}" == "windows" ]]; then
  prefer_windows_tar
  fix_native_keymap_checksums

  npm rebuild
  npm run postinstall
fi

mv .npmrc.bak .npmrc
# }}}

# package.json
cp package.json{,.bak}

setpath "package" "version" "${RELEASE_VERSION%-insider}"

replace 's|Microsoft Corporation|Rush Automations|' package.json
replace "s|--max-old-space-size=8192|--max-old-space-size=${MAX_OLD_SPACE_SIZE}|" package.json

cp resources/server/manifest.json{,.bak}

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  setpath "resources/server/manifest" "name" "Rush - Insiders"
  setpath "resources/server/manifest" "short_name" "Rush - Insiders"
else
  setpath "resources/server/manifest" "name" "Rush"
  setpath "resources/server/manifest" "short_name" "Rush"
fi

# announcements
replace "s|\\[\\/\\* BUILTIN_ANNOUNCEMENTS \\*\\/\\]|$( tr -d '\n' < ../announcements-builtin.json )|" src/vs/workbench/contrib/welcomeGettingStarted/browser/gettingStarted.ts

../undo_telemetry.sh

replace 's|Microsoft Corporation|Rush Automations|' build/lib/electron.ts
replace 's|([0-9]) Microsoft|\1 Rush Automations|' build/lib/electron.ts

if [[ "${OS_NAME}" == "linux" ]]; then
  # microsoft adds their apt repo to sources
  # unless the app name is code-oss
  # as we are renaming the application to vscodium
  # we need to edit a line in the post install template
  if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
    sed -i "s/code-oss/codium-insiders/" resources/linux/debian/postinst.template
  else
    sed -i "s/code-oss/codium/" resources/linux/debian/postinst.template
  fi

  # fix the packages metadata
  # code.appdata.xml
  sed -i 's|Visual Studio Code|Rush|g' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://rush-automations.com/|' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com/home/home-screenshot-linux-lg.png|https://rush-automations.com/|' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com|https://rush-automations.com|g' resources/linux/code.appdata.xml

  # control.template
  sed -i 's|Microsoft Corporation <vscode-linux@microsoft.com>|Rush Automations <hello@rush-automations.com>|'  resources/linux/debian/control.template
  sed -i 's|Visual Studio Code|Rush|g' resources/linux/debian/control.template
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://rush-automations.com/|' resources/linux/debian/control.template
  sed -i 's|https://code.visualstudio.com|https://rush-automations.com|g' resources/linux/debian/control.template

  # code.spec.template
  sed -i 's|Microsoft Corporation|Rush Automations|' resources/linux/rpm/code.spec.template
  sed -i 's|Visual Studio Code Team <vscode-linux@microsoft.com>|Rush Automations <hello@rush-automations.com>|' resources/linux/rpm/code.spec.template
  sed -i 's|Visual Studio Code|Rush|' resources/linux/rpm/code.spec.template
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://rush-automations.com/|' resources/linux/rpm/code.spec.template
  sed -i 's|https://code.visualstudio.com|https://rush-automations.com|g' resources/linux/rpm/code.spec.template

  # snapcraft.yaml
  sed -i 's|Visual Studio Code|Rush|' resources/linux/rpm/code.spec.template
elif [[ "${OS_NAME}" == "windows" ]]; then
  # code.iss
  sed -i 's|https://code.visualstudio.com|https://rush-automations.com|g' build/win32/code.iss
  sed -i 's|Microsoft Corporation|Rush Automations|' build/win32/code.iss
fi

cd ..
