#/bin/sh

set -e

sudo deluged
sudo deluge-web --fork --ssl
