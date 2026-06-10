#!/bin/bash
# Usage: ./strip_ota.sh OTA_input.bin output.bin

INPUT="$1"
OUTPUT="$2"

MAGIC_HEX="072e01d6bc10914fb28a352f82261a50"

if [[ -z "$INPUT" || -z "$OUTPUT" ]]; then
    echo "Usage: $0 OTA_input.bin output.bin"
    exit 1
fi

# Find the first byte offset of the magic hex string
OFFSET_HEX=$(xxd -p "$INPUT" | tr -d '\n' | grep -b -o "$MAGIC_HEX" | head -n1 | cut -d: -f1)

if [[ -z "$OFFSET_HEX" ]]; then
    echo "❌ Magic hex pattern not found in $INPUT"
    exit 1
fi

BYTE_OFFSET=$((OFFSET_HEX / 2))
echo "✅ Found firmware magic at byte offset $BYTE_OFFSET"

# Strip before the firmware starts
tail -c +$((BYTE_OFFSET + 1)) "$INPUT" > "$OUTPUT"

echo "🎉 Output saved to: $OUTPUT"
ls -lh "$OUTPUT"
