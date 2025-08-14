#!/bin/bash

# 設定顏色，讓輸出更易讀
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# --- 步驟 1: 檢查與準備 ---

# 抓取目前所在的分支名稱
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
MAIN_BRANCH="main" # 如果您的主要分支是 master，請改成 "master"

echo -e "${YELLOW}準備合併分支: ${CURRENT_BRANCH} -> ${MAIN_BRANCH}${NC}"

# 安全檢查：不可以在 main 分支上執行此腳本
if [ "$CURRENT_BRANCH" == "$MAIN_BRANCH" ]; then
  echo -e "${RED}錯誤: 您已經在 ${MAIN_BRANCH} 分支上，請切換到要合併的功能分支再執行此腳本。${NC}"
  exit 1
fi

# 安全檢查：確保工作區是乾淨的，沒有未提交的變更
if ! git diff-index --quiet HEAD --; then
    echo -e "${RED}錯誤: 您有尚未提交的變更，請先 commit 或 stash。${NC}"
    exit 1
fi

# --- 步驟 2: 同步與更新 ---

echo -e "\n${GREEN}正在更新本地與遠端分支...${NC}"

# 更新主要分支
git checkout $MAIN_BRANCH
git pull origin $MAIN_BRANCH

# 切換回功能分支
git checkout $CURRENT_BRANCH

# 將功能分支與最新的主要分支同步 (rebase)，這能讓合併歷史更乾淨
# 如果您不熟悉 rebase，可以註解掉這行，直接合併
git rebase $MAIN_BRANCH

# 將最新的功能分支推送到遠端
# 因為 rebase 了，需要強制推送，--force-with-lease 比 --force 更安全
git push origin $CURRENT_BRANCH --force-with-lease

# --- 步驟 3: 合併與推送 ---

echo -e "\n${GREEN}開始執行合併...${NC}"

# 切換回主要分支
git checkout $MAIN_BRANCH

# 合併功能分支
# --no-ff 會建立一個合併的 commit，讓歷史紀錄更清楚
#git merge --no-ff "$CURRENT_BRANCH"
git merge --no-ff -m "Merge branch '$CURRENT_BRANCH' into $MAIN_BRANCH" "$CURRENT_BRANCH"

# 檢查合併是否成功
if [ $? -ne 0 ]; then
  echo -e "${RED}合併時發生衝突！請手動解決衝突後再提交。${NC}"
  # 你可以選擇在這裡自動中止合併
  # git merge --abort
  exit 1
fi

echo -e "${GREEN}合併成功！正在推送到遠端倉庫...${NC}"

# 將合併後的 main 分支推送到遠端
git push origin $MAIN_BRANCH

# --- 步驟 4: 清理 ---

echo -e "\n${GREEN}正在清理已合併的分支...${NC}"

# 刪除遠端的功能分支
git push origin --delete $CURRENT_BRANCH

# 刪除本地的功能分支
git branch -d $CURRENT_BRANCH

# --- 步驟 5: 部署 (上版) ---

echo -e "\n${GREEN}====== 開始執行部署腳本 (上版) ======${NC}"

# 在這裡加上您的部署指令
# 這部分會根據您的專案類型和伺服器環境而有極大不同
# 以下為一些範例，請根據您的實際情況修改或替換

# 範例1: 如果是 Flutter Web 專案，可能需要編譯並上傳
# echo "正在建置 Flutter Web..."
# flutter build web --release
# rsync -avz ./build/web/ user@your-server.com:/var/www/my-project/

# 範例2: 如果是後端專案，可能需要 SSH 到伺服器去拉最新版並重啟服務
# ssh user@your-server.com "cd /path/to/your/app && git pull && pm2 restart app_name"

# 範例3: 簡單的提示訊息
echo "部署指令已執行 (請在此處替換成您真實的指令)。"

echo -e "\n${GREEN}🎉 全部完成！版本已合併並部署成功！${NC}"

exit 0