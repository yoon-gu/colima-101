#!/usr/bin/env sh
# notebooks/colab-pod-clone-uv311.ipynb 를 google-colab-cli로 CPU/T4 인스턴스에서 실행한다.
# 노트북 안에 설치+검증 셀이 모두 있어 colab exec 한 번으로 끝난다.
#
# 사전(최초 1회, 꼭 먼저!):
#   uv tool install "git+https://github.com/googlecolab/google-colab-cli"   # PyPI보다 최신
#   colab --auth=oauth2 whoami    # URL 승인 → 인증 코드 붙여넣기 → 본인 계정 출력되면 완료
#
# 사용법:
#   sh scripts/colab-run-notebook.sh           # CPU + T4 둘 다
#   sh scripts/colab-run-notebook.sh cpu       # CPU 인스턴스만
#   sh scripts/colab-run-notebook.sh t4        # T4 GPU 인스턴스만
#   NB=notebooks/다른노트북.ipynb TIMEOUT=2400 sh scripts/colab-run-notebook.sh
#
# 참고: 설치(131개)가 오래 걸리므로 exec 타임아웃을 넉넉히(기본 1800초) 준다.

NB="${NB:-notebooks/colab-pod-clone-uv311.ipynb}"
TIMEOUT="${TIMEOUT:-1800}"
WHICH="${1:-all}"

command -v colab >/dev/null 2>&1 || { echo "colab CLI 미설치: uv tool install google-colab-cli"; exit 1; }
[ -f "$NB" ] || { echo "노트북 파일 없음: $NB"; exit 1; }

# name, accel("" 또는 "--gpu T4") 를 받아 세션 생성→노트북 실행→로그→정리
run() {
    name="$1"; accel="$2"
    echo "================== [$name] 시작 ${accel:+($accel)} =================="
    # shellcheck disable=SC2086  # accel은 의도적으로 단어분리(빈 값이면 CPU)
    colab new -s "$name" $accel               || { echo "[$name] 세션 생성 실패"; return 1; }
    colab exec -s "$name" -f "$NB" --timeout "$TIMEOUT" || echo "[$name] exec 경고(타임아웃/일부 실패 가능) — 로그 확인"
    echo "------ [$name] 세션 로그 ------"
    colab log -s "$name" 2>/dev/null || true
    colab stop -s "$name" || true
    echo "================== [$name] 종료 =================="
    echo
}

case "$WHICH" in
    cpu) run podclone-cpu "" ;;
    t4)  run podclone-t4 "--gpu T4" ;;
    all) run podclone-cpu "" ; run podclone-t4 "--gpu T4" ;;
    *)   echo "사용법: $0 [cpu|t4|all]"; exit 1 ;;
esac
