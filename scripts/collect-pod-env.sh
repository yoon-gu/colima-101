#!/usr/bin/env sh
# Pod 쉘 안에서 실행하세요. 이미지를 재현하기 위한 환경 정보를 모읍니다.
# 사용법(쉘만 접근 가능할 때):
#   1) 이 파일 내용을 복사해 Pod 안에 붙여넣고 `sh collect-pod-env.sh` 실행
#   2) 또는 kubectl 접근이 되면:
#        kubectl cp collect-pod-env.sh <ns>/<pod>:/tmp/c.sh
#        kubectl exec -it <pod> -- sh /tmp/c.sh
# 결과는 /tmp/pod-env 디렉토리에 모이고, 마지막에 tar로 묶입니다.
# ⚠️ env 덤프에는 토큰(HF_TOKEN 등)이 포함될 수 있으니 외부로 옮기기 전 반드시 검수/마스킹하세요.

set +e
OUT=/tmp/pod-env
mkdir -p "$OUT"
echo "[*] 수집 시작 -> $OUT"

# --- OS / 베이스 이미지 단서 ---
cat /etc/os-release            > "$OUT/os-release.txt"      2>&1
uname -a                       > "$OUT/uname.txt"           2>&1

# --- 실제 실행 프로세스(entrypoint 힌트) / 작업 디렉토리 / 유저 ---
tr '\0' ' ' < /proc/1/cmdline  > "$OUT/pid1-cmdline.txt"    2>&1; echo >> "$OUT/pid1-cmdline.txt"
pwd                            > "$OUT/workdir.txt"         2>&1
id                             > "$OUT/user.txt"            2>&1
ls -la                         > "$OUT/workdir-listing.txt" 2>&1

# --- Python / pip ---
command -v python python3 pip pip3 > "$OUT/python-which.txt" 2>&1
python  --version              >> "$OUT/python-which.txt"    2>&1
python3 --version              >> "$OUT/python-which.txt"    2>&1
( pip freeze || pip3 freeze )  > "$OUT/requirements.txt"     2>&1

# --- conda (있으면) ---
if command -v conda >/dev/null 2>&1; then
  conda list                   > "$OUT/conda-list.txt"      2>&1
  conda env export             > "$OUT/environment.yml"     2>&1
fi

# --- CUDA / GPU (AI 환경 핵심) ---
python - > "$OUT/torch-cuda.txt" 2>&1 <<'PY'
try:
    import torch
    print("torch", torch.__version__)
    print("cuda_build", torch.version.cuda)
    print("cudnn", torch.backends.cudnn.version())
    print("is_available", torch.cuda.is_available())
except Exception as e:
    print("no torch:", e)
PY
nvcc --version                 > "$OUT/nvcc.txt"            2>&1
nvidia-smi                     > "$OUT/nvidia-smi.txt"      2>&1

# --- 시스템 패키지 목록(배포판별) ---
( dpkg -l || apk info -v || rpm -qa ) > "$OUT/system-packages.txt" 2>&1

# --- 환경변수 (검수 필요!) ---
env | sort                     > "$OUT/env-RAW-SECRETS.txt"  2>&1

# --- 묶기 ---
tar czf /tmp/pod-env.tgz -C /tmp pod-env 2>/dev/null
echo "[*] 완료. 아래 두 가지를 가져가세요(토큰 검수 후):"
echo "    - $OUT/requirements.txt"
echo "    - /tmp/pod-env.tgz  (kubectl cp <ns>/<pod>:/tmp/pod-env.tgz ./pod-env.tgz)"
echo
echo "===== requirements.txt 미리보기 ====="
head -50 "$OUT/requirements.txt"
echo
echo "===== torch / cuda ====="
cat "$OUT/torch-cuda.txt"
