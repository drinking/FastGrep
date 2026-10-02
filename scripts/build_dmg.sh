#!/usr/bin/env bash

# ==============================================================================
# FastGrep DMG Packaging Script
# 适用于本地及 GitHub Actions CI/CD 环境的自动打包脚本
# ==============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="FastGrep"
SCHEME_NAME="FastGrep"
PROJECT_FILE="${PROJECT_DIR}/FastGrep.xcodeproj"
DIST_DIR="${PROJECT_DIR}/dist"
BUILD_DIR="${PROJECT_DIR}/build"
DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
VOLUME_NAME="${APP_NAME}"

echo "=================================================="
echo "🚀 开始构建与打包 ${APP_NAME}..."
echo "📂 工程路径: ${PROJECT_FILE}"
echo "📦 输出目录: ${DIST_DIR}"
echo "=================================================="

# 1. 准备清理目录
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

# 2. Xcodebuild Release 模式编译
echo "🔨 正在编译 Release 版本..."
xcodebuild clean build \
    -project "${PROJECT_FILE}" \
    -scheme "${SCHEME_NAME}" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "${BUILD_DIR}" \
    CODE_SIGNING_ALLOWED=NO

APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "❌ 错误: 未能在预期路径找到编译产物: ${APP_PATH}"
    exit 1
fi

echo "✅ 编译成功: ${APP_PATH}"

# 3. 对 App 进行本地自签名 (Ad-hoc Sign) 确保沙盒与权限完整
echo "🔏 正在进行 Ad-hoc 签名..."
codesign --force --deep --sign - "${APP_PATH}" || true

# 4. 创建 DMG 载体
DMG_TEMP_DIR="${BUILD_DIR}/dmg_temp"
rm -rf "${DMG_TEMP_DIR}"
mkdir -p "${DMG_TEMP_DIR}"

echo "📋 正在组织 DMG 内容..."
cp -R "${APP_PATH}" "${DMG_TEMP_DIR}/"
# 创建到 Applications 的软链接
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# 检查是否有安装 create-dmg 工具，如果有则生成美观带箭头的 DMG，否则使用原生 hdiutil
if command -v create-dmg &> /dev/null; then
    echo "🎨 检测到 create-dmg，生成美化 DMG 镜像..."
    create-dmg \
        --volname "${VOLUME_NAME}" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 160 190 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 440 190 \
        --no-internet-enable \
        "${DMG_PATH}" \
        "${DMG_TEMP_DIR}" || true
fi

# 如果未生成（未安装 create-dmg 或失败），使用 macOS 内置的 hdiutil 进行标准打包
if [ ! -f "${DMG_PATH}" ]; then
    echo "📦 使用 macOS 原生 hdiutil 生成 DMG 镜像..."
    hdiutil create \
        -volname "${VOLUME_NAME}" \
        -srcfolder "${DMG_TEMP_DIR}" \
        -ov \
        -format UDZO \
        "${DMG_PATH}"
fi

# 5. 清理临时目录
rm -rf "${DMG_TEMP_DIR}"

# 6. 计算 SHA256 校验码
echo "🔐 正在生成 SHA256 校验和..."
(cd "${DIST_DIR}" && shasum -a 256 "${DMG_NAME}" > "${DMG_NAME}.sha256")

echo "=================================================="
echo "🎉 打包完成!"
echo "📦 DMG 文件: ${DMG_PATH}"
echo "🔑 SHA256: $(cat "${DMG_PATH}.sha256")"
echo "=================================================="
