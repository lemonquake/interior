#!/usr/bin/env bash
# Sets up (or refreshes) Sleep's server side on the VPS: the co-op relay, the lobby broker and the website/update host.
#   sudo bash install.sh     (from a folder holding this script, the files beside it and relay/sleep_relay.py)
# Safe to run again. Releases are uploaded by tools/release/publish.py.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
DEPLOY_USER=${SUDO_USER:-ubuntu}

id sleep >/dev/null 2>&1 || useradd --system --home-dir /opt/sleep --shell /usr/sbin/nologin sleep
install -d -m 0755 /opt/sleep /opt/sleep/relay
install -m 0644 "$HERE/relay/sleep_relay.py" /opt/sleep/relay/sleep_relay.py
install -d -o "$DEPLOY_USER" -g "$DEPLOY_USER" -m 0755 /srv/sleep /srv/sleep/site /srv/sleep/updates \
  /srv/sleep/updates/chunks /srv/sleep/downloads
install -m 0644 "$HERE/sleep-relay.service" /etc/systemd/system/sleep-relay.service

# lobby broker
if ! command -v mosquitto >/dev/null; then DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mosquitto >/dev/null; fi
install -m 0644 "$HERE/sleep-mosquitto.conf" /etc/mosquitto/conf.d/sleep.conf
install -m 0644 "$HERE/sleep.acl" /etc/mosquitto/sleep.acl

# website and updates
install -d -m 0755 /etc/caddy/sites
install -m 0644 "$HERE/sleep.caddy" /etc/caddy/sites/sleep.caddy
grep -q '^import /etc/caddy/sites/\*\.caddy' /etc/caddy/Caddyfile || printf '\nimport /etc/caddy/sites/*.caddy\n' >> /etc/caddy/Caddyfile
install -d -o caddy -g caddy -m 0755 /var/log/caddy
[ -f /var/log/caddy/sleep-access.log ] || install -o caddy -g caddy -m 0640 /dev/null /var/log/caddy/sleep-access.log
chown caddy:caddy /var/log/caddy/sleep-access.log
sudo -u caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null

ufw allow 25109/tcp comment 'Sleep relay control' >/dev/null
ufw allow 25110:25159/udp comment 'Sleep relay rooms' >/dev/null
ufw allow 25200:25599/udp comment 'Sleep relay friends' >/dev/null
ufw allow 1883/tcp comment 'Sleep lobby (MQTT)' >/dev/null

systemctl daemon-reload
systemctl enable --now sleep-relay mosquitto >/dev/null
systemctl restart sleep-relay mosquitto
systemctl reload caddy
echo "Sleep server side ready: relay $(systemctl is-active sleep-relay), lobby $(systemctl is-active mosquitto), caddy $(systemctl is-active caddy)"
