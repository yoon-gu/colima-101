#!/usr/bin/env sh
# AWS DLC 이미지를 받아 "우리 Pod의 베이스 레이어"와 같은지 대조한다.
# Pod = DLC(베이스) + 사내 앱 패키지(transformers/langchain 등). 따라서 여기서는
# DLC가 제공하는 부분(OS·python·torch/cuda/cudnn·SageMaker 학습 툴킷·apex·smdistributed)만 비교한다.
#
# 사전: docker + aws CLI + AWS 자격증명(ECR 접근). x86_64 권장(arm64는 에뮬레이션, 느림).
#
# 사용법:
#   sh compare-dlc.sh                                  # 기본: pytorch-training 2.4.0 / us-east-1
#   REGION=ap-northeast-2 sh compare-dlc.sh
#   IMAGE=<account>.dkr.ecr.<region>.amazonaws.com/pytorch-inference:2.4.0-gpu-py311-cu124-ubuntu22.04-sagemaker \
#       sh compare-dlc.sh                              # inference DLC 점검도 동일하게

set -e
ACCOUNT="${ACCOUNT:-763104351884}"
REGION="${REGION:-us-east-1}"
IMAGE="${IMAGE:-$ACCOUNT.dkr.ecr.$REGION.amazonaws.com/pytorch-training:2.4.0-gpu-py311-cu124-ubuntu22.04-sagemaker}"

echo "[*] 대상 이미지: $IMAGE"
echo "[*] ECR 로그인 ($REGION) ..."
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"

echo "[*] pull (수 GB, 시간 걸림) ..."
docker pull "$IMAGE"

echo
echo "================ DLC 베이스 레이어 (Pod 기대값과 대조) ================"
echo "기대(Pod): Ubuntu 22.04.x / Python 3.11.x / torch 2.4.0+cu124 / cuDNN 9.1.x /"
echo "          sagemaker-pytorch-training 2.8.1 / smdistributed 존재 / apex 존재"
echo "----------------------------------------------------------------------"
docker run --rm --entrypoint /bin/bash "$IMAGE" -lc '
  echo "[OS ]"; grep PRETTY_NAME /etc/os-release
  echo "[PY ]"; python --version
  python - <<PY
import importlib.metadata as md
def v(p):
    try: return md.version(p)
    except Exception: return "(없음)"
import torch
print("[torch]", torch.__version__, "| built cuda", torch.version.cuda, "| cudnn", torch.backends.cudnn.version())
print("[sagemaker-pytorch-training]", v("sagemaker-pytorch-training"))
print("[smdistributed-dataparallel]", v("smdistributed-dataparallel"))
print("[apex]", v("apex"))
PY
  echo "[smdistributed import]"; python -c "import smdistributed; print(\"  OK\")" 2>/dev/null || echo "  import 불가"
  echo "[apex import]";          python -c "import apex; print(\"  OK\")" 2>/dev/null || echo "  import 불가"
'
echo "======================================================================"
echo "위 값이 기대(Pod)와 일치하면 → 이 DLC가 Pod의 베이스 레이어가 맞다."
echo "(transformers/langchain 등 앱 패키지는 DLC엔 없음 — 그건 사내가 얹은 레이어)"
