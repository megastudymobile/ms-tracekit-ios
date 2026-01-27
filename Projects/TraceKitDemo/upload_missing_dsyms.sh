#!/bin/bash

# Firebase Crashlytics - 누락된 dSYM 수동 업로드 스크립트
# 사용법: ./upload_missing_dsyms.sh <dSYM 파일이 있는 디렉토리>

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔥 Firebase Crashlytics dSYM 수동 업로드 스크립트${NC}"
echo ""

# 1. GoogleService-Info.plist 경로 확인
GOOGLE_SERVICE_PLIST="./Resources/GoogleService-Info.plist"

if [ ! -f "$GOOGLE_SERVICE_PLIST" ]; then
    echo -e "${RED}❌ GoogleService-Info.plist 파일을 찾을 수 없습니다: $GOOGLE_SERVICE_PLIST${NC}"
    exit 1
fi

echo -e "${GREEN}✅ GoogleService-Info.plist 찾음: $GOOGLE_SERVICE_PLIST${NC}"

# 2. Firebase Crashlytics upload-symbols 스크립트 경로 찾기
# Tuist SPM 구조에서 Firebase SDK 경로
FIREBASE_SCRIPT=$(find ~/Library/Developer/Xcode/DerivedData -name "upload-symbols" 2>/dev/null | grep "firebase-ios-sdk" | head -n 1)

if [ -z "$FIREBASE_SCRIPT" ]; then
    echo -e "${RED}❌ Firebase upload-symbols 스크립트를 찾을 수 없습니다.${NC}"
    echo -e "${YELLOW}💡 먼저 Xcode에서 프로젝트를 빌드해주세요.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Firebase upload-symbols 스크립트 찾음: $FIREBASE_SCRIPT${NC}"

# 3. dSYM 경로 입력 받기
DSYM_PATH="$1"

if [ -z "$DSYM_PATH" ]; then
    echo ""
    echo -e "${YELLOW}📦 dSYM 파일을 찾는 방법:${NC}"
    echo "  1. Xcode > Window > Organizer"
    echo "  2. Archives 탭에서 빌드 우클릭 > 'Show in Finder'"
    echo "  3. .xcarchive 파일 우클릭 > '패키지 내용 보기'"
    echo "  4. dSYMs 폴더 경로를 복사"
    echo ""
    read -p "📂 dSYM 파일이 있는 디렉토리 경로를 입력하세요: " DSYM_PATH
fi

if [ ! -d "$DSYM_PATH" ]; then
    echo -e "${RED}❌ dSYM 디렉토리를 찾을 수 없습니다: $DSYM_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✅ dSYM 디렉토리 찾음: $DSYM_PATH${NC}"

# 4. dSYM 파일 목록 확인
DSYM_FILES=$(find "$DSYM_PATH" -name "*.dSYM" -type d)

if [ -z "$DSYM_FILES" ]; then
    echo -e "${RED}❌ dSYM 파일을 찾을 수 없습니다.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}📦 발견된 dSYM 파일:${NC}"
echo "$DSYM_FILES"
echo ""

# 5. GOOGLE_APP_ID 추출
GOOGLE_APP_ID=$(/usr/libexec/PlistBuddy -c "Print :GOOGLE_APP_ID" "$GOOGLE_SERVICE_PLIST" 2>/dev/null)

if [ -z "$GOOGLE_APP_ID" ]; then
    echo -e "${RED}❌ GOOGLE_APP_ID를 GoogleService-Info.plist에서 읽지 못했습니다.${NC}"
    exit 1
fi

echo -e "${GREEN}🆔 GOOGLE_APP_ID: $GOOGLE_APP_ID${NC}"
echo ""

# 6. 업로드 시작
echo -e "${YELLOW}📤 dSYM 파일 업로드 시작...${NC}"
echo ""

"$FIREBASE_SCRIPT" -gsp "$GOOGLE_SERVICE_PLIST" -p ios "$DSYM_PATH"

echo ""
echo -e "${GREEN}✅ dSYM 업로드 완료!${NC}"
echo -e "${YELLOW}💡 Firebase Console에서 5-10분 후 확인 가능합니다.${NC}"
