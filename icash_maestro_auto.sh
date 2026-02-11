#!/bin/bash

# --- 參數設定 ---
APP_NAME="icashPay_Debug"
BUNDLE_ID="com.example.myAwesomeApp0910"
# 指向您截圖中的 Maestro 腳本路徑
FLOW_FILE="/Users/aijinka/ios0120/new-workspace/ios0120.yaml"
BUILD_DIR="build/ios/iphonesimulator"
ZIP_NAME="${APP_NAME}_$(date +%Y%m%d).zip"

# Log 格式化
log() {
    echo -e "\033[1;34m====> $1\033[0m"
}

# 1. 環境修復與編譯 (切換為 --debug 模式)
log "正在修復 iOS 依賴並編譯模擬器版本 (Debug 模式)..."
flutter clean
flutter pub get

# 針對截圖中提到的 Module 'mobile_scanner' not found 進行修復
(cd ios && rm -rf Pods && rm -f Podfile.lock && pod install)

# 模擬器不支援 Release 模式，故改用 --debug
flutter build ios --simulator --debug

# 2. 打包 ZIP 提供給 QA
log "正在打包 Runner.app 為 ZIP 檔案..."
if [ -d "$BUILD_DIR/Runner.app" ]; then
    cd "$BUILD_DIR"
    # 使用 -ry 保持符號連結，避免 QA 解壓後 App 毀損
    zip -ry "../../../$ZIP_NAME" Runner.app > /dev/null
    cd - > /dev/null
    log "✅ 打包完成：./$ZIP_NAME"
else
    echo "❌ 錯誤：找不到編譯產出的 .app 檔案。"
    exit 1
fi

# 3. 安裝到模擬器
log "正在檢查模擬器並安裝 App..."
if ! xcrun simctl list devices | grep -q "Booted"; then
    log "⚠️ 未偵測到啟動中的模擬器，正在啟動預設模擬器..."
    open -a Simulator
    sleep 15 # 給予模擬器更多啟動時間
fi

xcrun simctl install booted "$BUILD_DIR/Runner.app"
log "✅ 安裝成功 (Bundle ID: $BUNDLE_ID)"

# 4. 執行 Maestro 測試
log "🧪 啟動 Maestro 測試：$FLOW_FILE"
# 確保腳本路徑正確並執行測試
maestro test "$FLOW_FILE"
