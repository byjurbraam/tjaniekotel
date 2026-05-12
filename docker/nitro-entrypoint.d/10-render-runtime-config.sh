#!/bin/sh
set -eu

escape_sed_replacement() {
    printf '%s' "$1" | sed -e 's/[#&]/\\&/g'
}

set_json_string() {
    file="$1"
    key="$2"
    value="$(escape_sed_replacement "$3")"

    if [ -f "$file" ]; then
        sed -i -E "s#\"$key\": \"[^\"]*\"#\"$key\": \"$value\"#g" "$file"
    fi
}

: "${NITRO_WEBSOCKET_URL:=ws://127.0.0.1/ws}"
: "${NITRO_ASSET_URL:=/assets}"
: "${NITRO_IMAGE_LIBRARY_URL:=/swf/c_images/}"
: "${NITRO_HOF_FURNI_URL:=/swf/dcr/hof_furni/}"
: "${NITRO_CAMERA_URL:=/usercontent/camera}"
: "${NITRO_CMS_URL:=}"

renderer_config="/usr/share/nginx/html/renderer-config.json"
ui_config="/usr/share/nginx/html/ui-config.json"

set_json_string "$renderer_config" "socket.url" "$NITRO_WEBSOCKET_URL"
set_json_string "$renderer_config" "asset.url" "$NITRO_ASSET_URL"
set_json_string "$renderer_config" "image.library.url" "$NITRO_IMAGE_LIBRARY_URL"
set_json_string "$renderer_config" "hof.furni.url" "$NITRO_HOF_FURNI_URL"

set_json_string "$ui_config" "camera.url" "$NITRO_CAMERA_URL"
set_json_string "$ui_config" "url.prefix" "$NITRO_CMS_URL"
