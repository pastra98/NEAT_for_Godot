#!/bin/sh
# quick hack yto check all resources referenced anywhere are present on filesystem.
# This is useful also to catch case-insensitive file names with wrong case (the application
# works just fine on Windows, but will fail on linux)
fgrep -r "res://" . | sed -e 's+^\([^:]*\):.*res://\([^\\"]*\)[\\"].*$+\1 \2+g' | while read f l; do [ -f "$l" ] || echo missing "$l" in "$f"; done
