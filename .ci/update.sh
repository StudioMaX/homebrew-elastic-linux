#!/usr/bin/env bash

set -euo pipefail

# example: 7.2.0
VERSION=$1
# override to test staging like so:
#   https://staging.elastic.co/7.2.0-abcd1234/downloads
DOWNLOAD_BASE=${DOWNLOAD_BASE:=https://artifacts.elastic.co/downloads}

DOWNLOAD_ARGS="tap=elastic/homebrew-tap"

log() {
  echo "[homebrew-updater] $1"
}

update() {
  FORMULA_FILE=$1
  ARTIFACT_PATH=$2

  NEW_URL="$DOWNLOAD_BASE/$ARTIFACT_PATH?$DOWNLOAD_ARGS"
#-E -e "s|^(\s*url.*-linux-.*\".*sha256) \".*\"$|\1 \"\"|g"
  log "Replacing the url, version, and emptying the sha256 of the formula '${FORMULA_FILE}'."
  /usr/bin/sed -i -E \
    -e "s|^(\s*url) \".*-linux-.*\"$|\1 \"$NEW_URL\"|" \
    -e "s|^(\s*version) \".*\"$|\1 \"$VERSION\"|" \
    -e '/^ *url \".*-linux-.*\"/,/^ *[^:]*:/s/sha256 \".*\"/sha256 \"\"/' \
    "$FORMULA_FILE"

  log "Installing '${FORMULA_FILE}'."
  if BREW_INSTALL_OUTPUT=$(brew install --formula "$FORMULA_FILE" 2>&1)
  then
    echo "$BREW_INSTALL_OUTPUT"
    log "Install successful."
  else
    echo "$BREW_INSTALL_OUTPUT"
    log "The install was unsuccessful, aborting."
    exit 1
  fi

  log "Picking up the reported new sha256."
  NEW_SHA256=$(echo "$BREW_INSTALL_OUTPUT" | awk '/sha256 / { gsub("\"","");print $2 }')

  if test -z "$NEW_SHA256"
  then
    log 'No new sha256 detected. Aborting.'
    exit 1
  fi

  log "Putting the new sha256 in place."
  /usr/bin/sed -i \
    -e "/^ *url \".*-linux-.*\"/,/^ *[^:]*:/s/sha256 \".*\"/sha256 \"$NEW_SHA256\"/" \
    "$FORMULA_FILE"

  brew uninstall --formula "$(basename "$FORMULA_FILE" .rb)"
}

log "Using brew: '$(which brew)'."

update "./Formula/apm-server-full.rb" "apm-server/apm-server-$VERSION-linux-x86_64.tar.gz"
update "./Formula/apm-server-oss.rb" "apm-server/apm-server-oss-$VERSION-linux-x86_64.tar.gz"
update "./Formula/auditbeat-full.rb" "beats/auditbeat/auditbeat-$VERSION-linux-x86_64.tar.gz"
update "./Formula/auditbeat-oss.rb" "beats/auditbeat/auditbeat-oss-$VERSION-linux-x86_64.tar.gz"
update "./Formula/elasticsearch-full.rb" "elasticsearch/elasticsearch-$VERSION-linux-x86_64.tar.gz"
update "./Formula/filebeat-full.rb" "beats/filebeat/filebeat-$VERSION-linux-x86_64.tar.gz"
update "./Formula/filebeat-oss.rb" "beats/filebeat/filebeat-oss-$VERSION-linux-x86_64.tar.gz"
update "./Formula/heartbeat-full.rb" "beats/heartbeat/heartbeat-$VERSION-linux-x86_64.tar.gz"
update "./Formula/heartbeat-oss.rb" "beats/heartbeat/heartbeat-oss-$VERSION-linux-x86_64.tar.gz"
update "./Formula/kibana-full.rb" "kibana/kibana-$VERSION-linux-x86_64.tar.gz"
update "./Formula/logstash-full.rb" "logstash/logstash-$VERSION-linux-x86_64.tar.gz"
update "./Formula/logstash-oss.rb" "logstash/logstash-oss-$VERSION-linux-x86_64.tar.gz"
update "./Formula/metricbeat-full.rb" "beats/metricbeat/metricbeat-$VERSION-linux-x86_64.tar.gz"
update "./Formula/metricbeat-oss.rb" "beats/metricbeat/metricbeat-oss-$VERSION-linux-x86_64.tar.gz"
update "./Formula/packetbeat-full.rb" "beats/packetbeat/packetbeat-$VERSION-linux-x86_64.tar.gz"
update "./Formula/packetbeat-oss.rb" "beats/packetbeat/packetbeat-oss-$VERSION-linux-x86_64.tar.gz"
