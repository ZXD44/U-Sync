#!/usr/bin/env bash

# ==============================================================================
# ยูซิงค์ (U-Sync) - Build, USB Install & GitHub Release Script
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# GitHub Config
GITHUB_REPO="ZXD44/U-Sync"
GITHUB_URL="https://github.com/$GITHUB_REPO"

# Project directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# 1. Setup Environment Paths
export PATH="/home/zirconx/development/flutter/bin:$PATH"
export ANDROID_HOME="/home/zirconx/Android/Sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

ADB_BIN="$ANDROID_HOME/platform-tools/adb"
if ! command -v "$ADB_BIN" &> /dev/null; then
    ADB_BIN="adb"
fi

echo -e "${CYAN}${BOLD}"
echo "============================================================"
echo "         🚀 ยูซิงค์ (U-Sync) - Build & Release Manager       "
echo "============================================================"
echo -e "${NC}"

INSTALL_FLAG=false
GITHUB_FLAG=false

for arg in "$@"; do
    if [ "$arg" == "--install" ] || [ "$arg" == "-i" ]; then
        INSTALL_FLAG=true
    fi
    if [ "$arg" == "--github" ] || [ "$arg" == "-g" ] || [ "$arg" == "--publish" ]; then
        GITHUB_FLAG=true
    fi
done

# Extract Version from pubspec.yaml
APP_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1 | tr -d ' "')
if [ -z "$APP_VERSION" ]; then
    APP_VERSION="1.0.0"
fi

echo -e "📦 กำลังเตรียมคอมไพล์เวอร์ชัน: ${BOLD}${GREEN}v${APP_VERSION}${NC}"
echo ""

echo -e "${YELLOW}📦 Step 1/3: Getting dependencies (flutter pub get)...${NC}"
flutter pub get

echo -e "${YELLOW}🔨 Step 2/3: Compiling Release APK (Optimized 64-bit arm64)...${NC}"
flutter build apk --release --target-platform android-arm64 --android-skip-build-dependency-validation

# 2. Output directory & Clean old APKs
RELEASE_DIR="$PROJECT_DIR/release"
mkdir -p "$RELEASE_DIR"
rm -f "$RELEASE_DIR"/*.apk

SRC_APK="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
DEST_APK="$RELEASE_DIR/U-Sync.apk"

if [ -f "$SRC_APK" ]; then
    echo -e "${YELLOW}📂 Step 3/3: Copying APK to release folder...${NC}"
    cp "$SRC_APK" "$DEST_APK"
    
    APK_SIZE=$(du -h "$DEST_APK" | cut -f1)
    
    echo -e "${GREEN}${BOLD}"
    echo "============================================================"
    echo "         🎉 BUILD SUCCESSFUL! APK IS READY                  "
    echo "============================================================"
    echo -e "${NC}"
    echo -e "📍 ${BOLD}Release Folder:${NC} $RELEASE_DIR"
    echo -e "📱 ${BOLD}APK File:${NC}       $DEST_APK (${APK_SIZE})"
    echo -e "🏷️  ${BOLD}Version:${NC}        v${APP_VERSION}"
    echo ""
else
    echo -e "${RED}❌ Error: APK output file was not found!${NC}"
    exit 1
fi

# ==============================================================================
# 🌐 GitHub Release Management (https://github.com/ZXD44/U-Sync)
# ==============================================================================
echo -e "${BLUE}${BOLD}------------------------------------------------------------${NC}"
echo -e "${BLUE}${BOLD}      🌐 GitHub Release & Auto-Update Controller            ${NC}"
echo -e "${BLUE}${BOLD}------------------------------------------------------------${NC}"
echo -e "🔗 GitHub Repo: ${CYAN}${GITHUB_URL}${NC}"
echo -e "⚡ In-App Updater URL: ${CYAN}https://api.github.com/repos/$GITHUB_REPO/releases/latest${NC}"
echo ""

DO_GITHUB="n"
if [ "$GITHUB_FLAG" = true ]; then
    DO_GITHUB="y"
else
    read -p "🐙 ต้องการอัปเดต / เผยแพร่เวอร์ชัน v$APP_VERSION ขึ้น GitHub หรือไม่? (y/N): " -n 1 -r REPLY || REPLY="n"
    echo ""
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        DO_GITHUB="y"
    fi
fi

if [ "$DO_GITHUB" = "y" ]; then
    echo -e "${CYAN}🚀 เริ่มต้นกระบวนการ GitHub Release...${NC}"
    
    # Initialize Git if needed
    if [ ! -d ".git" ]; then
        echo -e "${YELLOW}📂 กำลังกำหนดค่า Git repository...${NC}"
        git init -b main
        git remote add origin "$GITHUB_URL.git" || true
    fi

    # Ensure git author identity is set
    if [ -z "$(git config user.name 2>/dev/null || echo "")" ]; then
        git config user.name "ZXD44"
    fi
    if [ -z "$(git config user.email 2>/dev/null || echo "")" ]; then
        git config user.email "zxd44@users.noreply.github.com"
    fi

    # Check / set remote
    CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
    if [ -z "$CURRENT_REMOTE" ]; then
        git remote add origin "$GITHUB_URL.git"
    fi

    # Add all files & commit
    echo -e "${YELLOW}📝 กำลัง Commit ไฟล์และเตรียม Tag v$APP_VERSION...${NC}"
    git add .
    git commit -m "Release v$APP_VERSION: Update U-Sync APK and in-app updater" || true
    git branch -M main || true
    
    # Create tag
    git tag -f "v$APP_VERSION"

    echo ""
    echo -e "${GREEN}✓ เตรียมข้อมูลพร้อม Push ขึ้น GitHub!${NC}"
    echo -e "${CYAN}คำสั่งสำหรับ Push Release และ Asset:${NC}"
    echo -e "   ${BOLD}1. git push -u origin main --tags${NC}"
    
    if command -v gh &> /dev/null; then
        echo -e "${YELLOW}⚡ ตรวจพบ GitHub CLI (gh)! กำลังสร้าง Release อัตโนมัติ...${NC}"
        gh release create "v$APP_VERSION" "$DEST_APK#U-Sync.apk" \
            --title "U-Sync v$APP_VERSION" \
            --notes "🎬 U-Sync Release v$APP_VERSION - อัปเดตประสิทธิภาพและระบบซิงค์ Realtime" || true
        echo -e "${GREEN}✓ สร้าง GitHub Release สำเร็จ!${NC}"
    else
        echo -e "   ${BOLD}2. อัปโหลดไฟล์ APK ไปที่: ${CYAN}${GITHUB_URL}/releases/new${NC}"
        echo -e "      (ลากไฟล์ ${DEST_APK} ใส่ในช่อง Binary Assets)"
    fi
    echo ""
fi

# ==============================================================================
# 🔌 USB Debugging Installation (ADB)
# ==============================================================================
echo -e "${MAGENTA}${BOLD}------------------------------------------------------------${NC}"
echo -e "${MAGENTA}${BOLD}          🔌 Android USB Debugging Installation             ${NC}"
echo -e "${MAGENTA}${BOLD}------------------------------------------------------------${NC}"

DEVICES=$($ADB_BIN devices | grep -w "device" | awk '{print $1}' || true)

if [ -z "$DEVICES" ]; then
    echo -e "${YELLOW}⚠️  No Android devices detected via USB Debugging.${NC}"
    echo -e "${CYAN}💡 Tips to install via USB:${NC}"
    echo "   1. Enable Developer Options & USB Debugging on your phone."
    echo "   2. Connect phone via USB and allow USB debugging prompt."
    echo "   3. Run: ./build_apk.sh --install"
else
    DEVICE_COUNT=$(echo "$DEVICES" | wc -l)
    echo -e "${GREEN}✓ Found $DEVICE_COUNT device(s) connected:${NC}"
    echo "$DEVICES" | while read -r dev; do
        MODEL=$($ADB_BIN -s "$dev" shell getprop ro.product.model 2>/dev/null || echo "Android Device")
        echo -e "   📱 ${BOLD}$dev${NC} ($MODEL)"
    done
    echo ""

    DO_INSTALL="y"
    if [ "$INSTALL_FLAG" = false ]; then
        read -p "📲 Do you want to install APK to connected device(s) now? (Y/n): " -n 1 -r REPLY || REPLY="y"
        echo ""
        if [[ ! "$REPLY" =~ ^[Yy]$ ]] && [[ ! -z "$REPLY" ]]; then
            DO_INSTALL="n"
        fi
    fi

    if [ "$DO_INSTALL" = "y" ]; then
        echo "$DEVICES" | while read -r dev; do
            echo -e "${CYAN}🚀 Installing to $dev...${NC}"
            $ADB_BIN -s "$dev" install -r "$DEST_APK"
            echo -e "${GREEN}✓ Successfully installed to $dev!${NC}"
        done
    else
        echo -e "${YELLOW}⏭️  Skipped USB installation.${NC}"
    fi
fi

echo ""
echo -e "${GREEN}${BOLD}✨ All Done!${NC}"
