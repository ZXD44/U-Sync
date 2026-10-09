#!/usr/bin/env bash

# ==============================================================================
# 🚀 ยูซิงค์ (U-Sync) - Build & Release Manager Menu
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

# Setup Environment Paths
export PATH="/home/zirconx/development/flutter/bin:$PATH"
export ANDROID_HOME="/home/zirconx/Android/Sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
export PATH="/home/zirconx/.local/bin:$PATH"

ADB_BIN="$ANDROID_HOME/platform-tools/adb"
if ! command -v "$ADB_BIN" &> /dev/null; then
    ADB_BIN="adb"
fi

get_current_version() {
    APP_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1 | tr -d ' "')
    if [ -z "$APP_VERSION" ]; then
        APP_VERSION="1.0.0"
    fi
    echo "$APP_VERSION"
}

get_current_build() {
    BUILD_NUM=$(grep '^version:' pubspec.yaml | cut -d'+' -f2 | tr -d ' "' || echo "1")
    echo "$BUILD_NUM"
}

set_new_version() {
    local NEW_VER="$1"
    if [ -z "$NEW_VER" ]; then
        return
    fi

    # 1. Update pubspec.yaml
    CURRENT_BUILD=$(get_current_build)
    NEW_BUILD=$((CURRENT_BUILD + 1))
    sed -i "s/^version: .*/version: $NEW_VER+$NEW_BUILD/" pubspec.yaml

    # 2. Update update_service.dart
    sed -i "s/static const String currentVersion = '[^']*';/static const String currentVersion = '$NEW_VER';/" lib/services/update_service.dart

    echo -e "${GREEN}✓ อัปเดตเวอร์ชันเป็น v$NEW_VER (Build $NEW_BUILD) สำเร็จ! (ซิงค์ทั้ง pubspec.yaml และ UpdateService)${NC}"
}

RELEASE_DIR="$PROJECT_DIR/release"
DEST_APK="$RELEASE_DIR/U-Sync.apk"

do_build_apk() {
    local VER=$(get_current_version)
    local BUILD=$(get_current_build)
    echo ""
    echo -e "${CYAN}${BOLD}🔨 [1/2] ดาวน์โหลดและตรวจสอบ Dependencies (flutter pub get)...${NC}"
    flutter pub get

    echo -e "${YELLOW}${BOLD}⚙️  [2/2] กำลังคอมไพล์ Release APK v$VER+$BUILD (ARM64 + ARMv7 พร้อม R8 Shrink)...${NC}"
    flutter build apk --release --android-skip-build-dependency-validation --target-platform android-arm,android-arm64

    mkdir -p "$RELEASE_DIR"
    rm -f "$RELEASE_DIR"/*.apk
    cp "$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk" "$DEST_APK"

    APK_SIZE=$(du -h "$DEST_APK" | cut -f1)
    echo ""
    echo -e "${GREEN}${BOLD}============================================================${NC}"
    echo -e "${GREEN}${BOLD}✓ คอมไพล์ Universal Release APK สำเร็จ!${NC}"
    echo -e "${GREEN}${BOLD}============================================================${NC}"
    echo -e "📍 ไฟล์ APK:     ${BOLD}$DEST_APK${NC}"
    echo -e "📦 ขนาดไฟล์:     ${BOLD}${GREEN}$APK_SIZE${NC} (ลดขนาด 37.5% ด้วย R8 + ตัด x86_64)"
    echo -e "🏷️  เวอร์ชัน:      ${BOLD}v${VER} (Build ${BUILD})${NC}"
    echo -e "📱 สถาปัตยกรรม:  ${BOLD}ARM64-v8a + ARMv7 (รองรับมือถือ Android ทุกรุ่น)${NC}"
    echo ""
}

do_install_usb() {
    echo ""
    echo -e "${MAGENTA}${BOLD}🔌 ตรวจสอบการเชื่อมต่อ USB Debugging (ADB)...${NC}"
    if [ ! -f "$DEST_APK" ]; then
        echo -e "${RED}❌ ไม่พบไฟล์ APK ในโฟลเดอร์ release กรุณาเลือก Build ก่อน!${NC}"
        return 1
    fi

    DEVICES=$($ADB_BIN devices | grep -w "device" | awk '{print $1}' || true)
    if [ -z "$DEVICES" ]; then
        echo -e "${YELLOW}⚠️  ไม่พบมือถือ Android ที่เปิดโหมด USB Debugging${NC}"
        echo -e "💡 วิธีเปิด: เข้า การตั้งค่า > ตัวเลือกสำหรับนักพัฒนา > เปิด 'การแก้ไขข้อบกพร่อง USB'"
        return 1
    fi

    echo "$DEVICES" | while read -r dev; do
        MODEL=$($ADB_BIN -s "$dev" shell getprop ro.product.model 2>/dev/null || echo "Android Device")
        echo -e "${CYAN}📲 กำลังติดตั้งลงเครื่อง: ${BOLD}$dev${NC} ($MODEL)..."
        $ADB_BIN -s "$dev" install -r "$DEST_APK"
        echo -e "${GREEN}✓ ติดตั้งลง $dev สำเร็จเรียบร้อย!${NC}"
    done
    echo ""
}

do_github_release() {
    local VER=$(get_current_version)
    local BUILD=$(get_current_build)
    echo ""
    echo -e "${BLUE}${BOLD}🐙 ขั้นตอนการอัปโหลด Release ขึ้น GitHub (v$VER)...${NC}"
    
    read -p "🏷️ ต้องการใช้เวอร์ชัน v$VER หรือเปลี่ยนใหม่? (กด Enter ใช้ v$VER / พิมพ์เวอร์ชันใหม่เช่น 1.0.5): " -r CUSTOM_VER
    if [ -n "$CUSTOM_VER" ]; then
        set_new_version "$CUSTOM_VER"
        VER="$CUSTOM_VER"
        BUILD=$(get_current_build)
        echo -e "${YELLOW}กำลังคอมไพล์ APK ใหม่สำหรับเวอร์ชัน v$VER...${NC}"
        do_build_apk
    fi

    if [ ! -f "$DEST_APK" ]; then
        echo -e "${YELLOW}⚡ ไม่พบไฟล์ APK ล่าสุด กำลังเริ่มคอมไพล์ APK...${NC}"
        do_build_apk
    fi

    if ! command -v gh &> /dev/null; then
        echo -e "${RED}❌ ไม่พบคำสั่ง gh (GitHub CLI)${NC}"
        return 1
    fi

    echo ""
    echo -e "${CYAN}${BOLD}📝 ระบุรายละเอียดสิ่งที่ทำ / อัปเดตในเวอร์ชันนี้ (Release Notes):${NC}"
    echo -e "${YELLOW}(พิมพ์ข้อความ เช่น '- แก้ไขบัค... - เพิ่มฟีเจอร์...' หรือกด Enter เพื่อใช้ค่ามาตรฐาน):${NC}"
    read -p "👉 รายละเอียด: " -r USER_NOTES

    if [ -z "$USER_NOTES" ]; then
        USER_NOTES="🎬 U-Sync v$VER:
- จำกัด 1 คนต่อ 1 ห้อง ป้องกันข้อมูลห้องทับซ้อน
- ปรับเวลานับถอยหลังลบห้องว่างเป็น 10 วินาที ลบเร็วและไม่แลค
- วิดีโอเล่นต่อเนื่องตาม Server Time ไม่มีวันหยุด
- ปรับปรุงการเล่นต่อเนื่องตอนดับหน้าจอมือถือ (Foreground Media & Screen-off sync)"
    fi

    # Check if release exists
    if gh release view "v$VER" &>/dev/null; then
        echo -e "${YELLOW}⚡ อัปเดตไฟล์ APK ใน Release v$VER ที่มีอยู่แล้ว...${NC}"
        gh release upload "v$VER" "$DEST_APK#U-Sync.apk" --clobber
        gh release edit "v$VER" --notes "$USER_NOTES"
    else
        echo -e "${YELLOW}⚡ กำลังสร้าง Release ใหม่ v$VER บน GitHub...${NC}"
        gh release create "v$VER" "$DEST_APK#U-Sync.apk" \
            --title "U-Sync v$VER" \
            --notes "$USER_NOTES"
    fi

    echo ""
    echo -e "${GREEN}${BOLD}============================================================${NC}"
    echo -e "${GREEN}${BOLD}✓ เผยแพร่ขึ้น GitHub Release (v$VER) สำเร็จเรียบร้อย!${NC}"
    echo -e "${GREEN}${BOLD}============================================================${NC}"
    echo -e "🔗 ลิงก์ Release:  ${CYAN}${GITHUB_URL}/releases/tag/v$VER${NC}"
    echo -e "📥 ดาวน์โหลด APK:  ${CYAN}${GITHUB_URL}/releases/download/v$VER/U-Sync.apk${NC}"
    echo -e "📝 รายละเอียด:"
    echo -e "${YELLOW}$USER_NOTES${NC}"
    echo ""
}

prompt_change_version() {
    local CURRENT_VER=$(get_current_version)
    local CURRENT_BUILD=$(get_current_build)
    echo ""
    echo -e "🏷️  เวอร์ชันปัจจุบัน: ${BOLD}${GREEN}v${CURRENT_VER} (Build ${CURRENT_BUILD})${NC}"
    read -p "👉 กรุณาระบุเวอร์ชันใหม่ (เช่น 1.0.5 หรือ 1.1.0): " -r NEW_VER
    if [ -n "$NEW_VER" ]; then
        set_new_version "$NEW_VER"
    else
        echo -e "${YELLOW}ไม่มีการเปลี่ยนแปลงเวอร์ชัน${NC}"
    fi
    echo ""
}

# Check direct CLI flags
if [ "$1" == "--build" ] || [ "$1" == "-b" ]; then
    do_build_apk
    exit 0
elif [ "$1" == "--install" ] || [ "$1" == "-i" ]; then
    do_build_apk
    do_install_usb
    exit 0
elif [ "$1" == "--github" ] || [ "$1" == "-g" ]; then
    do_github_release
    exit 0
elif [ "$1" == "--all" ] || [ "$1" == "-a" ]; then
    do_build_apk
    do_github_release
    do_install_usb || true
    exit 0
fi

# ==============================================================================
# 📋 Interactive Menu
# ==============================================================================
clear
APP_VERSION=$(get_current_version)
APP_BUILD=$(get_current_build)
echo -e "${CYAN}${BOLD}"
echo "============================================================"
echo "         🚀 ยูซิงค์ (U-Sync) - Build & Release Manager       "
echo "============================================================"
echo -e "${NC}"
echo -e "🏷️  เวอร์ชันปัจจุบัน: ${BOLD}${GREEN}v${APP_VERSION} (Build ${APP_BUILD})${NC}"
echo -e "🔗 GitHub Repo:     ${BLUE}${GITHUB_URL}${NC}"
echo -e "📦 โฟลเดอร์ Release: ${YELLOW}${RELEASE_DIR}/${NC}"
echo ""
echo -e "${BOLD}เลือกการทำงานที่ต้องการ:${NC}"
echo -e "  ${GREEN}1.${NC} 🔨 ${BOLD}Build APK เท่านั้น${NC} (คอมไพล์ v$APP_VERSION ลง release/)"
echo -e "  ${MAGENTA}2.${NC} 📱 ${BOLD}Build APK + ติดตั้งลงมือถือทันที (USB ADB)${NC}"
echo -e "  ${BLUE}3.${NC} 🐙 ${BOLD}อัปโหลด APK ขึ้น GitHub Release${NC} (กรอก Release Notes & เปลี่ยนเวอร์ชันได้)"
echo -e "  ${CYAN}4.${NC} 🚀 ${BOLD}ทำทั้งหมด (Build + อัปขึ้น GitHub พร้อม Release Notes + ติดตั้งลงเครื่อง)${NC}"
echo -e "  ${YELLOW}5.${NC} 📲 ${BOLD}ติดตั้งไฟล์ APK ที่มีอยู่แล้วลงมือถือ (USB)${NC}"
echo -e "  ${BOLD}6.${NC} 🏷️  ${BOLD}เปลี่ยนเลขเวอร์ชันแอป${NC} (ปัจจุบัน v$APP_VERSION)"
echo -e "  ${RED}0.${NC} ❌ ออกจากโปรแกรม"
echo ""

read -p "👉 กรุณาเลือกหมายเลข (0-6) [ค่าเริ่มต้น 1]: " -r CHOICE || CHOICE="1"
CHOICE=${CHOICE:-1}

case "$CHOICE" in
    1)
        do_build_apk
        ;;
    2)
        do_build_apk
        do_install_usb
        ;;
    3)
        do_github_release
        ;;
    4)
        do_github_release
        do_install_usb || true
        ;;
    5)
        do_install_usb
        ;;
    6)
        prompt_change_version
        ;;
    0)
        echo -e "${YELLOW}ยกเลิกการทำงาน${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}ตัวเลือกไม่ถูกต้อง!${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}${BOLD}✨ เสร็จสิ้นการทำงาน!${NC}"
