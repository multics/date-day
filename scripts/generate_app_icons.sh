#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
source_image="$project_dir/Artwork/DateDay-AppIcon-Source.png"
master_image="$project_dir/Artwork/DateDay-AppIcon-Master-1024.png"
icon_dir="$project_dir/DateDay/Assets.xcassets/AppIcon.appiconset"
srgb_profile="/System/Library/ColorSync/Profiles/sRGB Profile.icc"

if [[ ! -f "$source_image" ]]; then
    print -u2 "Missing source image: $source_image"
    exit 1
fi

sips --matchTo "$srgb_profile" "$source_image" --out "$master_image" >/dev/null
sips --resampleHeightWidth 1024 1024 "$master_image" >/dev/null

generate_icon() {
    local filename=$1
    local pixels=$2

    sips \
        --resampleHeightWidth "$pixels" "$pixels" \
        "$master_image" \
        --out "$icon_dir/$filename" \
        >/dev/null
}

generate_icon AppIcon-16.png 16
generate_icon AppIcon-16@2x.png 32
generate_icon AppIcon-32.png 32
generate_icon AppIcon-32@2x.png 64
generate_icon AppIcon-128.png 128
generate_icon AppIcon-128@2x.png 256
generate_icon AppIcon-256.png 256
generate_icon AppIcon-256@2x.png 512
generate_icon AppIcon-512.png 512
generate_icon AppIcon-512@2x.png 1024
