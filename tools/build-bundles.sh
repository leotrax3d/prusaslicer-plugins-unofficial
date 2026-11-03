#!/usr/bin/env bash
#
# Assembles the combined bundles in bundles/ from the individual plugins.
#
# Each bundles/<id>/ holds a manifest.json and a plugins.txt naming the plugin
# directories to merge. Their .lua files are copied flat into dist/bundles/<id>/.
# Shared modules such as labels.lua exist once per plugin; a module that appears
# in two members with different content would make one plugin load the other's
# copy, so that is an error rather than a silent overwrite. Fix it by making the
# copies identical.

set -euo pipefail

out=${1:-dist/bundles}
status=0

for bundle in bundles/*/; do
    id=$(basename "$bundle")
    target="$out/$id"
    rm -rf "$target"
    mkdir -p "$target"
    cp "$bundle/manifest.json" "$target/"

    while read -r member; do
        [ -z "$member" ] && continue
        src="plugins/$member"
        if [ ! -d "$src" ]; then
            echo "ERROR: $id lists '$member', but $src does not exist"
            status=1
            continue
        fi
        for file in "$src"/*.lua; do
            name=$(basename "$file")
            if [ -f "$target/$name" ]; then
                if ! cmp -s "$file" "$target/$name"; then
                    echo "ERROR: $id: $name differs between members (conflict at $file)"
                    status=1
                fi
                continue
            fi
            cp "$file" "$target/"
        done
    done < "$bundle/plugins.txt"

    echo "$id -> $target: $(cd "$target" && ls | tr '\n' ' ')"
done

exit $status
