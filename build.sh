#!/bin/sh
set -e
cd /opt/conf
luarocks make --local
env
kong start
