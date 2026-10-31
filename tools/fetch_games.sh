#!/usr/bin/env bash
# Pulls the other games that run on office computers into res://games/ and
# points their res:// paths at their new folder. Not committed (see .gitignore);
# the office build runs this, and so can you before running the office locally.
#   tools/fetch_games.sh
set -euo pipefail
cd "$(dirname "$0")/.."
fetch() {
	local name=$1 repo=$2
	rm -rf "games/$name"
	git clone -q --depth 1 "https://github.com/$repo" "games/$name"
	(cd "games/$name" && rm -rf .git .github tools project.godot export_presets.cfg ./*.md)
	find "games/$name" \( -name '*.gd' -o -name '*.tscn' -o -name '*.tres' -o -name '*.gdshader' \) \
		-exec sed -i "s#res://#res://games/$name/#g" {} +
}
fetch pong humble-house-studios/phone-pong
