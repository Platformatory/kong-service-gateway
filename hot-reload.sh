#!/bin/sh
set -e
cd /opt/conf
luarocks --local make
/usr/local/bin/kong reload
