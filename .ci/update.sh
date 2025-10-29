#!/usr/bin/env bash

set -euo pipefail

# example: 7.2.0
VERSION=$1
# override to test staging like so:
#   https://staging.elastic.co/7.2.0-abcd1234/downloads
DOWNLOAD_BASE=${DOWNLOAD_BASE:=https://artifacts.elastic.co/downloads}

DOWNLOAD_ARGS="tap=elastic/homebrew-tap"
TAP_NAME="studiomax/elastic-linux"

log() {
  echo "[homebrew-updater] $1"
}

# Detect current OS/arch for brew fetch
detect_platform() {
  local uname_s uname_m os arch
  uname_s=$(uname -s)
  uname_m=$(uname -m)

  case "$uname_s" in
    Darwin) os="darwin" ;;
    Linux) os="linux" ;;
    *) log "Unsupported OS: $uname_s"; exit 1 ;;
  esac

  case "$uname_m" in
    arm64|aarch64) arch="aarch64" ;;
    x86_64) arch="x86_64" ;;
    *) log "Unsupported architecture: $uname_m"; exit 1 ;;
  esac

  echo "$os/$arch"
}

CURRENT_PLATFORM=$(detect_platform)

update() {
  local formula_file=$1
  local formula_name
  formula_name=$(basename "${formula_file%.rb}")

  log "Updating formula: $formula_file"

  # Extract available OS and arch values from formula
  local os_list arch_list
  os_list=$(grep -E '^\s*os ' "$formula_file" | sed -E 's/.*os (.*)/\1/' | tr -d '"' | tr ',' '\n' | awk -F: '{print $2}' | xargs)
  arch_list=$(grep -E '^\s*arch ' "$formula_file" | sed -E 's/.*arch (.*)/\1/' | tr -d '"' | tr ',' '\n' | awk -F: '{print $2}' | xargs)

  log "Detected OS list: $os_list"
  log "Detected arch list: $arch_list"

  # Update version in formula
  /usr/bin/sed -i -E "s|^(\s*version\s+\").*(\")|\1${VERSION}\2|" "$formula_file"

  # Determine base URL (without ?tap=...)
  local base_url
  base_url=$(grep -E '^\s*url\s+"https:\/\/artifacts\.elastic\.co' "$formula_file" | sed -E 's/.*"(https[^"]+)".*/\1/' | sed 's|\?.*||')

  log "Base URL: $base_url"

  # Now iterate all os/arch combos
  for os in $os_list; do
    for arch in $arch_list; do
      local platform="${os}/${arch}"
      local url="${base_url//\#\{os\}/${os}}"
      url="${url//\#\{arch\}/${arch}}"
      url="${url//\#\{version\}/${VERSION}}"

      log "Processing $platform → $url"

      local sha256=""
      # fallback to curl + sha256sum for other platforms
      if curl -fsSL "$url" -o /tmp/tmp.tar.gz; then
        sha256=$(shasum -a 256 /tmp/tmp.tar.gz | awk '{print $1}')
        rm -f /tmp/tmp.tar.gz
      else
        log "Failed to download $url"
      fi

      if [[ -n "$sha256" ]]; then
        log "SHA256 for $platform: $sha256"
      else
        log "No sha256 found for $platform"
      fi
    done
  done

  log "Installing '$TAP_NAME/$formula_name'."
  if BREW_INSTALL_OUTPUT=$(brew install --formula "$TAP_NAME/$formula_name" 2>&1)
  then
    echo "$BREW_INSTALL_OUTPUT"
    log "Install successful."
  else
    echo "$BREW_INSTALL_OUTPUT"
    log "The install was unsuccessful, aborting."
    exit 1
  fi

  brew uninstall --formula "$TAP_NAME/$formula_name"
}

log "Using brew: '$(which brew)'."

update "./Formula/apm-server-full.rb"

if [[ $VERSION =~ ^7\.* ]]
then
  update "./Formula/apm-server-oss.rb"
fi

update "./Formula/auditbeat-full.rb"
update "./Formula/auditbeat-oss.rb"
update "./Formula/elasticsearch-full.rb"
update "./Formula/filebeat-full.rb"
update "./Formula/filebeat-oss.rb"
update "./Formula/heartbeat-full.rb"
update "./Formula/heartbeat-oss.rb"
update "./Formula/kibana-full.rb"
update "./Formula/logstash-full.rb"
update "./Formula/logstash-oss.rb"
update "./Formula/metricbeat-full.rb"
update "./Formula/metricbeat-oss.rb"
update "./Formula/packetbeat-full.rb"
update "./Formula/packetbeat-oss.rb"
