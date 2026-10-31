#!/usr/bin/env bash
# Pulls the other games that run on office computers into res://games/ and
# points their res:// paths at their new folder. Not committed (see .gitignore);
# the office build runs this, and so can you before running the office locally.
#   tools/fetch_games.sh              fetch only
#   tools/fetch_games.sh --autoloads  also add the games' autoloads to
#                                     project.godot (the office build does this;
#                                     locally, `git checkout project.godot` after)
# A game's autoload names and class_names must not clash with this game's.
set -euo pipefail
cd "$(dirname "$0")/.."
fetch() {
	local name=$1 repo=$2
	rm -rf "games/$name"
	git clone -q --depth 1 "https://github.com/$repo" "games/$name"
	# Keep the game's autoloads (e.g. Game, Save), re-pointed at its folder.
	sed -n '/^\[autoload\]/,/^\[/{/^[A-Za-z_]*=/p}' "games/$name/project.godot" \
		| sed "s#res://#res://games/$name/#" > "games/$name/autoloads.txt"
	(cd "games/$name" && rm -rf .git .github tools tests docs integration build project.godot export_presets.cfg ./*.md)
	find "games/$name" \( -name '*.gd' -o -name '*.tscn' -o -name '*.tres' -o -name '*.gdshader' \) \
		-exec sed -i "s#res://#res://games/$name/#g" {} +
}
fetch pong humble-house-studios/phone-pong
fetch proof humble-house-studios/proof-hand
fetch loot humble-house-studios/Loot-Machine
fetch cube humble-house-studios/rubix

if [ "${1:-}" = "--autoloads" ]; then
	lines=$(cat games/*/autoloads.txt)
	if [ -n "$lines" ]; then
		grep -q '^\[autoload\]' project.godot || printf '\n[autoload]\n\n' >> project.godot
		while IFS= read -r line; do
			sed -i "/^\[autoload\]/a $line" project.godot
		done <<< "$lines"
	fi
fi
