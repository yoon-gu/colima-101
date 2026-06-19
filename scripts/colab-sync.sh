#!/usr/bin/env sh
# 로컬 패키지 목록을 원격 Colab 런타임에 설치해 환경을 "내 로컬"에 맞춘다.
# google-colab-cli(=`colab`)를 감싼 런북 스크립트.
#
# 사전 준비(최초 1회, 꼭 먼저!):
#   uv tool install "git+https://github.com/googlecolab/google-colab-cli"   # PyPI보다 최신
#   colab --auth=oauth2 whoami    # URL 승인 → 인증 코드 붙여넣기 → 본인 계정 출력되면 완료
#   GCP 서비스(BigQuery 등)가 필요하면: colab --auth adc 사용
#
# 사용법:
#   sh scripts/colab-sync.sh <session> <requirements.txt> [GPU]
#   예) sh scripts/colab-sync.sh mysync colab-sync/requirements-top.txt T4
#   예) sh scripts/colab-sync.sh mysync requirements-pod.txt           # CPU 세션
#
# 참고: Colab 세션은 휘발성이라 새 세션마다 install을 다시 돌려야 한다(그래서 스크립트화).
set -e

SESSION="${1:?세션 이름이 필요합니다. 예: mysync}"
REQ="${2:?requirements 파일 경로가 필요합니다}"
GPU="$3"   # T4 | L4 | G4 | H100 | A100 (생략 시 CPU)

[ -f "$REQ" ] || { echo "오류: '$REQ' 파일이 없습니다."; exit 1; }
command -v colab >/dev/null 2>&1 || { echo "오류: colab CLI 미설치. 'uv tool install google-colab-cli' 먼저 실행."; exit 1; }

echo "[1/3] 세션 생성: $SESSION ${GPU:+(GPU: $GPU)}"
colab new -s "$SESSION" ${GPU:+--gpu "$GPU"}

echo "[2/3] 패키지 설치(uv→pip 폴백): $REQ"
colab install -s "$SESSION" -r "$REQ"

echo "[3/3] 설치 결과 검증"
colab exec -s "$SESSION" -f scripts/verify-colab-env.py

echo
echo "완료. 종료하려면: colab stop -s $SESSION"
