#!/bin/bash
set -e

echo "🚀 Starting firmware patcher..."
echo "[0] Setting up workdir..."

mkdir -p work
cp /workspace/*.zip work/ 2>/dev/null || { echo "❌ No OTA .zip file found in directory!" && exit 1; }
cp /workspace/strip_ota.sh work/ || { echo "❌ strip_ota.sh not found!" && exit 1; }
cp -r /workspace/usr work/ || { echo "❌ usr/ directory not found!" && exit 1; }

cd work

ZIP_FILE=$(ls *.zip | head -n 1)
echo "→ Using firmware file: $ZIP_FILE"

echo "[1] Stripping firmware..."
bash ./strip_ota.sh "$ZIP_FILE" FW96580A.bin
echo "→ Backing up original firmware..."
cp FW96580A.bin /workspace/FW96580A.orig.bin

echo "[2] Detecting rootfs partition..."
python3 /opt/Novatek-FW-info/NTKFWinfo.py -i FW96580A.bin > fwinfo.txt
PART_ID=$(grep -wi "rootfs" fwinfo.txt | awk '{print $1}')
[ -z "$PART_ID" ] && echo "❌ rootfs partition not found" && exit 1
echo "→ Found rootfs partition ID: $PART_ID"

echo "[3] Extracting rootfs partition..."
python3 /opt/Novatek-FW-info/NTKFWinfo.py -i FW96580A.bin -u $PART_ID

echo "[4] Creating and extracting to rootfs/"
mkdir -p rootfs
cd rootfs
cpio -idmv < ../FW96580A.bin-uncomp_partitionID$PART_ID >/dev/null 2>&1
cd ..

# Grab owner from existing bin directory to match firmware IDs
OWNER=$(stat -c '%u:%g' rootfs/bin)
chown $OWNER rootfs
mv FW96580A.bin-uncomp_partitionID$PART_ID FW96580A.bin-uncomp_partitionID$PART_ID.bak

echo "[5] Enabling telnet and inetd in rootfs..."
sed -i 's|^# telnetd|telnetd|g' rootfs/etc/init.d/S25_Net
sed -i 's|^# inetd|inetd|g' rootfs/etc/init.d/S15_NvtAppInit
echo "[6] Rebuilding rootfs image..."
cd rootfs
find . | cpio -o --format=newc > ../FW96580A.bin-uncomp_partitionID$PART_ID 2>/dev/null
cd ..

echo "[7] Repacking rootfs firmware..."
python3 /opt/Novatek-FW-info/NTKFWinfo.py -i FW96580A.bin -c $PART_ID

echo "[8] Detecting usr partition (rootfs1)..."
USR_PART_ID=$(grep -wi "rootfs1" fwinfo.txt | awk '{print $1}')
[ -z "$USR_PART_ID" ] && USR_PART_ID=12
echo "→ Using usr partition ID: $USR_PART_ID"

echo "[9] Extracting usr partition (UBIFS)..."
python3 /opt/Novatek-FW-info/NTKFWinfo.py -i FW96580A.bin -u $USR_PART_ID

echo "[10] Locating dynamic UBIFS rootfs folder and copying usr/ directory..."
BASE_DIR="FW96580A.bin-uncomp_partitionID$USR_PART_ID"
TARGET_DIR=$(find $BASE_DIR -type d -name "rootfs" | head -n 1)
[ -z "$TARGET_DIR" ] && echo "❌ Could not find dynamic rootfs inside UBIFS extraction" && exit 1

echo "→ Found UBIFS rootfs at: $TARGET_DIR"
cp -r usr/* $TARGET_DIR/usr/

# Ensure the copied files are executable
echo "→ Applying permissions..."
chmod +x $TARGET_DIR/usr/bin/traccar_client.sh $TARGET_DIR/usr/bin/isp_demon || true

echo "[11] Repacking usr firmware (UBIFS)..."
python3 /opt/Novatek-FW-info/NTKFWinfo.py -i FW96580A.bin -c $USR_PART_ID

echo "[12] Exporting patched firmware..."
cp FW96580A.bin /workspace/FW96580A.bin

echo "✅ Firmware rebuild complete! Temporary files left in work/ for inspection."
echo "💾 Output saved to your folder as FW96580A.bin"
echo "💾 Backup saved as FW96580A.orig.bin"
