#!/usr/bin/env sh
# Docker 이미지 안의 설치된 패키지를 Colab 동기화용 requirements 파일로 추출.
# (freeze-local.sh 의 Docker 이미지 버전 — "이미지 환경을 Colab에 맞추기"용)
#
# 사용법:
#   sh scripts/freeze-from-image.sh <image> [출력경로]
#   예) sh scripts/freeze-from-image.sh pod-clone:cpu
#
# 결과(기본): colab-sync/requirements-image.txt  (.gitignore 처리됨)
#   - PyPI 설치 가능한 name==version 라인만 (로컬경로 '@ file://' 제외)
#   - torch 류의 +cpu/+cuXXX 로컬 라벨은 제거해 Colab이 자기 플랫폼 휠을 받게 함

IMAGE="${1:?Docker 이미지 이름이 필요합니다. 예: pod-clone:cpu}"
OUT="${2:-colab-sync/requirements-image.txt}"
mkdir -p "$(dirname "$OUT")"

docker run --rm "$IMAGE" python -m pip freeze 2>/dev/null \
  | grep -E '^[A-Za-z0-9._-]+==' \
  | grep -v ' @ ' \
  | sed -E 's/(==[0-9][0-9A-Za-z.]*)\+[0-9A-Za-z.]+/\1/' \
  > "$OUT"

echo "[image] $IMAGE"
echo "[out  ] $(wc -l < "$OUT" | tr -d ' ') packages -> $OUT"
echo
echo "다음: sh scripts/colab-sync.sh <session> $OUT [GPU]"
