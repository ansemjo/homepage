#!/usr/bin/env bash
# deploy a new static hugo dist to webroot

WEBROOT=/srv/http/semjonov
OWNER=root
DIST=${1:?give dist tarball as argument}

set -e
cd "$WEBROOT"
read -p "deploy $DIST to $PWD? (y/n) " -n1 ok
echo
[[ $ok == 'y' ]]
set -x
rm -rf *
tar xf "$DIST"
chown $OWNER:$OWNER -R .
restorecon -R .
