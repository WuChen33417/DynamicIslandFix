#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodebuild >/dev/null || { echo '需要 macOS 和 Xcode 26+。' >&2; exit 1; }
swift test
xcodebuild -project YumEdit.xcodeproj -scheme YumEdit -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= \
  PRODUCT_BUNDLE_IDENTIFIER=com.dynamicislandfix.research \
  build
app=build/DerivedData/Build/Products/Release-iphoneos/YumEdit.app
test -d "$app"
mkdir -p build/ipa/Payload dist
# Always assemble a fresh Payload; never repackage upstream's old IPA.
rm -rf build/ipa/Payload/YumEdit.app
cp -R "$app" build/ipa/Payload/
rm -f dist/DynamicIslandFix-unsigned.ipa
(cd build/ipa && /usr/bin/zip -qry ../../dist/DynamicIslandFix-unsigned.ipa Payload)
shasum -a 256 dist/DynamicIslandFix-unsigned.ipa
echo '未签名 IPA 已生成；手机安装前须自行签名。设备实验需要 profile 授予 App Group。'
