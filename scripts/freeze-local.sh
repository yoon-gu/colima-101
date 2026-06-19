#!/usr/bin/env sh
# 로컬(또는 지정한) Python 환경의 패키지를 Colab 동기화용 requirements 파일로 추출.
# Colab은 Linux/x86_64이므로, 설치 불가한 로컬 경로(@ file://)·URL 설치 라인은 걸러낸다.
#
# 사용법:
#   sh freeze-local.sh                              # 현재 python3 기준
#   PYBIN=/path/to/venv/bin/python sh freeze-local.sh   # 특정 venv/conda 환경 지정
#
# 결과(colab-sync/ 디렉토리, .gitignore 처리됨 — 머신별 생성물):
#   requirements-full.txt   전체(pip freeze) 중 PyPI 설치 가능한 라인만
#   requirements-top.txt    top-level만(다른 패키지의 의존성이 아닌 것) — Colab 동기화 권장

PYBIN="${PYBIN:-python3}"
OUT=colab-sync
mkdir -p "$OUT"

# ' @ '(로컬경로/URL 설치)와 editable(-e) 라인은 Colab에서 재현 불가 → 제외
"$PYBIN" -m pip freeze 2>/dev/null \
  | grep -E '^[A-Za-z0-9._-]+==' \
  | grep -v ' @ ' \
  > "$OUT/requirements-full.txt"

"$PYBIN" -m pip list --not-required --format=freeze 2>/dev/null \
  | grep -E '^[A-Za-z0-9._-]+==' \
  | grep -v ' @ ' \
  > "$OUT/requirements-top.txt"

echo "[full] $(wc -l < "$OUT/requirements-full.txt" | tr -d ' ') packages -> $OUT/requirements-full.txt"
echo "[top ] $(wc -l < "$OUT/requirements-top.txt"  | tr -d ' ') packages -> $OUT/requirements-top.txt"
echo
echo "권장: requirements-top.txt 로 동기화 (Colab 기본 환경의 torch/CUDA를 덜 망가뜨림)."
echo "다음: sh scripts/colab-sync.sh <session> $OUT/requirements-top.txt [GPU]"
