# syntax=docker/dockerfile:1
# =============================================================================
# Pod(SageMaker Distribution, conda 기반) 근사 재현 Dockerfile — 자급식
#
# Pod 환경(수집 확인):
#   Ubuntu 22.04.5 / Python 3.11.9 / torch 2.4.0+cu124 / CUDA 12.4 / cuDNN 9.1
#   transformers 4.49.0, langchain 1.2.10, langgraph 1.0.10 등 (requirements.txt)
#
# 설계 메모:
#   - Pod의 pip freeze 중 다수는 `@ file:///tmp/...` 로컬 휠이지만 전부 PyPI 정식 버전.
#     따라서 SMD 베이스 없이 python:3.11-slim 위에 정확한 버전으로 재현한다.
#   - 환경 전용·분산학습용 패키지는 외부 재현 불가라 제외.
#     (그런 기능이 필요하면 실제 SMD 이미지를 베이스로 써야 함)
#
# 빌드 (이 디렉토리에서):
#   로컬 개발 (colima, arm64, GPU 없음 → CPU torch):
#       docker build -t dev:cpu .
#   GPU 클러스터 충실 재현 (x86_64 + CUDA 12.4):
#       docker build --platform linux/amd64 --build-arg TORCH_INDEX=cu124 \
#                    -t dev:gpu .
#
# 실행:
#   docker run --rm -it dev:cpu python
#   docker run --rm -it --gpus all dev:gpu python   # GPU 노드에서
# =============================================================================

FROM python:3.11-slim

# cpu | cu124  (로컬 기본 cpu, GPU 충실 재현은 cu124)
ARG TORCH_INDEX=cpu

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HF_HOME=/opt/hf-cache

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        build-essential \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# 1) torch 계열 먼저 — Pod와 동일 버전, CUDA 매칭이 핵심
RUN pip install \
        torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 \
        --index-url "https://download.pytorch.org/whl/${TORCH_INDEX}"

# 2) 나머지 top-level 라이브러리 (Pod에서 확인한 정확한 버전)
COPY requirements.txt .
RUN pip install -r requirements.txt

# 3) 설치 검증 — 빌드 시점에 핵심 import가 되는지 확인
RUN python - <<'PY'
import torch, transformers, datasets, accelerate
import langchain, langgraph, langsmith, openai, anthropic, chromadb
print("torch       ", torch.__version__, "cuda?", torch.cuda.is_available())
print("transformers", transformers.__version__)
print("langchain   ", langchain.__version__)
print("langgraph   ", getattr(langgraph, "__version__", "ok"))
print("OK: all core imports succeeded")
PY

CMD ["python"]
