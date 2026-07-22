#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SWIFT_DIR="$ROOT_DIR/usb8-restore"
SOURCE_BOOT_DIR="$ROOT_DIR/boot"
ASSET_DIR="$SWIFT_DIR/Sources/Usb8RestoreSwift/Resources/BootAssets"

mkdir -p "$ASSET_DIR"

swift "$SWIFT_DIR/Scripts/encrypt_boot_assets.swift" "$SOURCE_BOOT_DIR" "$ASSET_DIR"
