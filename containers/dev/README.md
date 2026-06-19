# dev 컨테이너 (개발 편의용)

**개발을 편하게** 하기 위해, 우리 코드가 실제로 도는 Pod을 로컬에 재현합니다.
NVIDIA GPU가 필요한 부분은 Colab T4로 검증합니다.

> **실제 Pod 베이스 = AWS PyTorch training DLC** (사내 커스텀, conda/Jupyter).
> env `SAGEMAKER_TRAINING_MODULE=sagemaker_pytorch_container.training:main` +
> 내부 태그 `…py311gpu-pt240-cu124-aws-dlc-train…` 으로 확인 →
> `pytorch-training:2.4.0-gpu-py311-cu124-ubuntu22.04-sagemaker` 계열.
> 현 `Dockerfile`은 `python:3.11-slim`(Debian) 기반 **경량 근사 재현**(휠 실행엔 충분).
> 충실 재현이 필요하면 위 DLC를 베이스로 사용. (태그의 `u2004`는 사내 명명 오류 — 실제 OS는 Ubuntu 22.04)

## 확정 스택 (실측 검증 완료)

| 항목 | 값 |
|---|---|
| OS | Ubuntu 22.04.5 LTS |
| Python | 3.11.9 |
| torch | 2.4.0+cu124 (CUDA 12.4 · cuDNN 9.1.0) |
| 핵심 | transformers 4.49.0 · tokenizers 0.21.1 · huggingface-hub 0.26.5 · datasets 3.2.0 · accelerate 1.2.0 · langchain 1.2.10 · langgraph 1.0.10 · langsmith 0.7.13 · openai 2.26.0 · anthropic 0.84.0 · chromadb 1.3.6 · numpy 1.26.4 · pydantic 2.12.5 |

| 검증 방식 | Python | 패키지 | torch / GPU |
|---|---|---|---|
| `colab-uv311.ipynb` ⭐ (Colab+uv) | **3.11.9** | **20/20 일치** | **2.4.0+cu124** · CPU `False` / **T4 `True` (Tesla T4)** |
| 로컬 Docker 이미지 | 3.11.x | 20/20 일치 | 2.4.0 · colima는 GPU 없음(CPU) |

## 구성

| 파일 | 용도 |
|---|---|
| `Dockerfile` | 자급식 재현 Dockerfile (CPU/GPU 빌드 인자, 빌드 시 import 검증) |
| `requirements.txt` | Pod top-level 라이브러리 정확 버전 고정 |
| `colab-uv311.ipynb` | uv로 Python 3.11.9 venv 생성 → 131개 패키지 + torch cu124 설치 → 검증 |

## A) 로컬 Docker 이미지로 재현 (NVIDIA 없이 CPU 검증)

```bash
cd containers/dev
docker build -t dev:cpu .
docker run --rm -it dev:cpu python

# GPU 클러스터 충실 재현(x86_64 + CUDA 12.4)
docker build --platform linux/amd64 --build-arg TORCH_INDEX=cu124 -t dev:gpu .
```

## B) Colab T4에서 NVIDIA GPU로 검증

저장소 루트에서 (colab-cli 설치·인증은 [최상위 README](../../README.md) 참고):

```bash
sh scripts/colab-run-notebook.sh t4    # 또는 cpu
# 기본 노트북이 이 컨테이너의 colab-uv311.ipynb 입니다.
```

`uv venv --python 3.11.9` 로 standalone CPython을 받아 별도 venv에 설치합니다.
- 이 3.11.9는 **venv/서브프로세스**입니다(노트북 셀 커널은 3.12 그대로). 실제 코드는
  `/content/py311/bin/python script.py` 또는 `uv run`으로 실행하세요.
- torch는 cu124로 **강제 재설치**합니다(`--reinstall-package torch torchvision torchaudio`).
  requirements가 cu121을 먼저 깔면 "이미 충족"으로 건너뛰기 때문.

## 환경 비교 (Pod ↔ Colab ↔ 재현)

| 항목 | 우리 Pod | Colab 런타임 (실측) | 재현 |
|---|---|---|---|
| OS | Ubuntu 22.04.5 LTS | Ubuntu 22.04.5 LTS ✅ | Ubuntu 22.04 / Colab 동일 |
| Python | 3.11.9 | 3.12.13 (시스템) | uv venv 3.11.9 ✅ |
| torch | 2.4.0+cu124 | 기본 설치 시 cu121 | 2.4.0+cu124 ✅ (강제 재설치) |
| CUDA(런타임) | 12.4 | torch 번들 12.4 | torch 번들 12.4 ✅ |
| cuDNN | 9.1.0 (torch 번들) | 프레임워크별 번들(TF 9.3.0 / 기본 torch 9.19.0) | torch 번들 9.1.0 ✅ |
| GPU(하드웨어) | NVIDIA (모델 미상·**T4 아님**) | Tesla T4 | ⚠️ T4는 대체 GPU (하드웨어 불일치) |

## 주의

- **prebuilt 휠만 사용** → CUDA 런타임/cuDNN은 torch 휠이 결정(Pod과 동일). 시스템
  nvcc/CUDA toolkit 버전 차이는 무관(휠에 컴파일된 커널 포함).
- ⚠️ **GPU 하드웨어는 일치 대상이 아님**: T4는 NVIDIA 코드 경로 테스트용 대체재.
  compute capability(T4=sm_75) 의존 코드는 Pod GPU에서 결과/성능이 다를 수 있음.
- **헤드리스 numpy ABI**: numpy 다운그레이드 후 같은 커널 import 시 `numpy.dtype size changed`
  에러 → 검증/스모크는 별도 인터프리터(venv python)에서 실행. 인터랙티브면 Restart 후 재실행.
- **세션은 휘발성**: 새 Colab 세션마다 설치 재실행 필요.
- 환경 전용·분산 인프라 패키지(apex, smdistributed 등)는 외부 재현 불가라 제외(개발엔 불필요).
  운영 추론 job 환경은 [`inference`](../inference/) 컨테이너 참고.
