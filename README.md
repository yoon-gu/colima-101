# colima-101

## 이 저장소의 목적 (왜 만들었나)

- 우리 코드는 **NVIDIA GPU가 달린 Ubuntu Pod**(SageMaker)에서 돌아갑니다.
- 하지만 개발은 **Apple Silicon Mac(M5, 32GB)** 에서 합니다 — NVIDIA/CUDA가 없습니다.
- 그래서 작성한 코드를 **그 Pod과 최대한 동일한 환경**에서 검증하려고:
  1. Pod의 패키지 환경을 **로컬 Docker 이미지(`pod-clone`)** 로 재현하고,
  2. **NVIDIA 하드웨어가 필요한 부분은 Colab T4 인스턴스**로 해결합니다.
- **확정 스택**: Python **3.11.9** / **torch 2.4.0+cu124** (CUDA 12.4 · cuDNN 9.1) +
  HuggingFace / LangChain / LangGraph. (T4에서 GPU 연산까지 실측 검증)

이를 위한 작업은 세 갈래입니다.

- **A.** Colab T4에서 그 환경(+NVIDIA GPU)을 돌리기 ← 핵심
- **B.** 같은 패키지 환경을 로컬 Docker 이미지(`pod-clone`)로 재현하기
- **C.** (그 토대로) macOS에 colima로 Docker + Kubernetes 깔기

> 아래 **TL;DR**만 보면 바로 돌릴 수 있습니다. 배경/이유가 궁금하면 [상세](#배경--상세)로.

---

## TL;DR — 바로 돌리기 (결론)

### 목표 A. Colab에서 AI 환경 돌리기 ⭐ (가장 흔함)

**0) 최초 1회: colab-cli 설치 + 인증** (안 하면 이후 명령이 멈춥니다)

```bash
uv tool install "git+https://github.com/googlecolab/google-colab-cli"  # PyPI보다 최신인 git 버전
colab --auth=oauth2 whoami    # 출력 URL을 브라우저로 승인 → 인증 코드 붙여넣기 → 계정 출력되면 OK
```
> `colab`은 `~/.local/bin/colab`에 깔립니다. 못 찾으면 PATH에 `~/.local/bin` 추가.

**1) 노트북 실행** — 확정 환경 = **Python 3.11.9 + torch 2.4.0+cu124** (NVIDIA T4):

```bash
# ⭐ 확정 — T4(NVIDIA)에서 Pod과 동일하게 (Python 3.11.9 + torch cu124 + GPU)
NB=colab-pod-clone-uv311.ipynb sh scripts/colab-run-notebook.sh t4

# GPU 없이 패키지 버전만 빠르게 확인 (torch cu124 줄은 CPU에선 불필요)
NB=colab-pod-clone-uv311.ipynb sh scripts/colab-run-notebook.sh cpu
```

GUI가 편하면 `colab-pod-clone-uv311.ipynb`를 Colab에서 열어
**Runtime → Change runtime type → T4 → Run all** 해도 동일합니다.

> ⚠️ colab-cli는 **본인 Colab 계정의 컴퓨트(쿼터/구독)** 를 씁니다. T4는 등급에 따라 안 잡힐 수 있음.

### 목표 B. 로컬에 Docker 이미지로 재현

```bash
docker build -f Dockerfile.sagemaker -t pod-clone:cpu .   # 로컬 개발용(CPU)
docker run --rm -it pod-clone:cpu python                  # torch/transformers/langchain... 그대로

# GPU 클러스터 충실 재현(x86_64 + CUDA 12.4)
docker build --platform linux/amd64 --build-arg TORCH_INDEX=cu124 -f Dockerfile.sagemaker -t pod-clone:gpu .
```

### 목표 C. macOS에 colima로 Docker + Kubernetes

```bash
brew install colima docker kubectl
colima start --kubernetes        # Docker 런타임 + k3s 함께 기동, kubectl 컨텍스트 자동 설정
```

---

## 검증 결과 (실측 완료)

| 방식 | Python | 핵심 패키지 | GPU / torch 빌드 |
|---|---|---|---|
| `colab-pod-clone-uv311.ipynb` (uv venv) ⭐ | **3.11.9** | **20/20 일치** | CPU `False` / **T4 `True`** · torch cu121 |
| `colab-cu124-experiment.ipynb` (cu124 정확 매칭) | 3.11.9 | torch 계열 | **T4 `True` · torch 2.4.0+cu124 / cuda 12.4 / cudnn 9.1** |
| `colab-pod-clone.ipynb` (Colab 기본 커널) | 3.12.13 | 20/20 일치 | CPU·T4 모두 확인 · torch cu121 |
| 로컬 `pod-clone` Docker 이미지 | 3.11.x | 20/20 일치 | colima는 GPU 없음(CPU) |

> torch의 CUDA 빌드까지 Pod와 동일하게(**cu124**) 맞추고 싶으면
> [CUDA 빌드까지 정확히 맞추기](#cuda-빌드까지-정확히-맞추기-cu124) 참고. T4에서 GPU 연산까지 검증됨.

핵심 스택: torch 2.4.0 / transformers 4.49.0 / tokenizers 0.21.1 / huggingface-hub 0.26.5 /
datasets 3.2.0 / accelerate 1.2.0 / langchain 1.2.10 / langgraph 1.0.10 / langsmith 0.7.13 /
openai 2.26.0 / anthropic 0.84.0 / chromadb 1.3.6 / numpy 1.26.4 / pydantic 2.12.5.

---

## 배경 & 상세

### 1. macOS에 colima로 Docker + Kubernetes

**환경**: macOS (Apple Silicon, aarch64) · macOS Virtualization.Framework · Homebrew

**설치 버전**: Colima 0.10.3 · Docker CLI 29.6.0(Server 29.5.2) · Kubernetes(k3s) v1.35.0 · kubectl 1.36.2

```bash
brew install colima docker kubectl
colima start --kubernetes
```

**테스트(검증 완료)**:

```bash
docker run --rm hello-world          # "Hello from Docker!"
kubectl get nodes -o wide            # 노드 colima → Ready (control-plane)
kubectl get pods -A                  # coredns / local-path-provisioner / metrics-server Running
# 실제 워크로드: nginx 배포 → Running → "Welcome to nginx!" 응답 확인 → 정리
```

**참고 명령어**:

```bash
colima start --kubernetes --cpu 4 --memory 8   # 리소스 조정(기본 2코어/2GiB)
colima status / stop / delete                  # 상태 / 중지 / VM 삭제
brew services start colima                      # 로그인 시 자동 시작
```

### 2. Pod 환경 → 로컬 Docker 이미지 재현

쉘에만 접근 가능한 Pod(여기선 **SageMaker Distribution**, conda 기반)의 환경을 로컬 Docker
이미지로 복제합니다.

**핵심 전략**: `pip freeze` 전체를 베끼지 않습니다. conda/SageMaker 이미지의 freeze는 다수가
`@ file:///tmp/...` 로컬 휠이거나 환경 전용 패키지라 재현 불가입니다. 대신 **직접 import 하는
top-level 라이브러리만 정확한 버전으로 고정**하고 pip가 나머지를 풀게 합니다.

| 파일 | 용도 |
|---|---|
| `scripts/collect-pod-env.sh` | Pod 안에서 전체 환경 정보 수집(OS·pip·conda·CUDA·시스템 패키지) → tar |
| `scripts/quick-summary.sh` | OS / Python / torch+CUDA / 핵심 라이브러리만 한 화면 요약(스크린샷용) |
| `scripts/key-versions.sh` | LangChain/LangGraph/HuggingFace 핵심 패키지 버전만 추출 |
| `requirements-pod.txt` | 확인한 top-level 라이브러리 정확 버전 고정 |
| `Dockerfile.sagemaker` | 자급식 재현 Dockerfile (CPU/GPU 빌드 인자, 빌드 시 import 검증 포함) |
| `Dockerfile.template` | 일반 재현용 주석 템플릿 |

**절차**: Pod에서 `sh quick-summary.sh`로 버전 확인(스크린샷이 손입력보다 효율적) →
`requirements-pod.txt` 맞춤 → 위 [목표 B](#목표-b-로컬에-docker-이미지로-재현)로 빌드.

재현 환경: Ubuntu 22.04 / Python 3.11.9 / torch 2.4.0(+cu124) / 위 핵심 스택.

> ⚠️ apex, smdistributed, 환경 전용·분산학습용 패키지는 외부에서 재현 불가라 제외했습니다.
> 그런 기능이 필요하면 실제 SMD 이미지를 베이스로 쓰세요.

### 3. 이미지/로컬 패키지 → Colab 동기화 (google-colab-cli)

위 2번이 "Pod → 로컬 이미지"였다면, 이건 반대로 **그 패키지들을 원격 Colab 런타임에 설치해
Colab을 우리 환경에 맞추는** 작업입니다. [google-colab-cli](https://github.com/googlecolab/google-colab-cli)(Google 공식)로 자동화합니다.

| 파일 | 용도 |
|---|---|
| `scripts/freeze-from-image.sh` | **Docker 이미지** 안의 패키지 → `colab-sync/requirements-image.txt` 추출 |
| `scripts/freeze-local.sh` | 로컬 venv/conda 환경 → `colab-sync/requirements-{full,top}.txt` 추출 |
| `scripts/colab-sync.sh` | `colab new → install -r → exec(검증)` 런북 (세션·requirements·GPU 인자) |
| `scripts/colab-run-notebook.sh` | 노트북을 colab-cli로 CPU·T4에서 실행 (`NB=...`로 노트북 지정) |
| `scripts/verify-colab-env.py` | Colab에서 핵심 라이브러리 버전 출력(비교용) |
| `colab-pod-clone.ipynb` | 131개 패키지 임베드 자급식 노트북. **Python = Colab 기본(3.12)** |
| `colab-pod-clone-uv311.ipynb` | **uv로 Python 3.11.9 venv** 생성 후 설치+검증. 이미지의 파이썬까지 정확히 일치 |
| `colab-cu124-experiment.ipynb` | **torch를 cu124까지 정확히** 맞추는 최소 실험(+ 실제 T4 GPU 연산 검증) |

#### 왜 두 개의 노트북인가 (이 repo의 핵심 교훈)

- 현재 **Colab 런타임은 Python 3.12.13**이고, **google-colab-cli는 가속기(CPU/GPU/TPU)만
  고를 수 있을 뿐 런타임 버전(=Python 버전)은 선택 못 합니다.** (`colab new --help`로 확인 가능)
- 패키지 핀만 맞추면 되면 → `colab-pod-clone.ipynb` (3.12에서도 20/20 일치 확인됨).
- **Python 3.11.9까지 정확히** 맞춰야 하면 → **`colab-pod-clone-uv311.ipynb`**.
  `uv venv --python 3.11.9`로 standalone CPython을 받아 별도 venv에 설치합니다.
  - 이 3.11.9는 **venv/서브프로세스**입니다(노트북 셀 커널은 3.12 그대로). 실제 코드는
    `/content/py311/bin/python script.py` 또는 `uv run`으로 실행하세요.
  - NVIDIA 드라이버는 시스템 레벨이라 **venv에서도 GPU(`cuda? True`)가 잡힙니다** (T4 실측 확인).
  - uv라 설치가 매우 빠릅니다(144패키지 ≈ 1.3초).

#### CUDA 빌드까지 정확히 맞추기 (cu124)

기본 설치는 `torch==2.4.0` → PyPI 기본 빌드(**cu121**)가 깔립니다(GPU는 됨). Pod의
`torch 2.4.0+cu124`까지 정확히 맞추려면 PyTorch **cu124 인덱스**에서 받습니다:

```bash
uv pip install --python /content/py311/bin/python \
    torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 \
    --index-url https://download.pytorch.org/whl/cu124
```

**T4 실측 결과**(`colab-cu124-experiment.ipynb`): `torch 2.4.0+cu124` / built cuda `12.4` /
cudnn `9.1.0` / `cuda available True` / Tesla T4(드라이버 580.82.07) / 실제 GPU matmul 정상.
→ Pod의 torch·CUDA·cuDNN을 모두 정확히 재현.

> cu124 휠은 `nvidia-*-cu12 12.4` 런타임 라이브러리(약 2GB)를 함께 가져옵니다. **GPU 런타임에서만**
> 의미가 있고, CPU 런타임에선 불필요하니 생략하세요(cu121/기본으로 충분). 전체 환경에 적용하려면
> `requirements-image.txt` 설치 **뒤에** 위 명령으로 torch만 덮어쓰면 됩니다.

#### 헤드리스 실행 시 주의 (numpy ABI)

`colab exec`로 노트북을 돌릴 때, numpy를 다운그레이드(2.x→1.26.4)한 뒤 **같은 커널에서 바로
import하면** `numpy.dtype size changed ... ABI` 에러가 납니다. 그래서 노트북의 검증/스모크
셀은 **별도 인터프리터(`%%python3` 또는 venv python)** 에서 돌립니다. 인터랙티브로 Run all 할
때는 다운그레이드 후 **Runtime → Restart session** 후 검증 셀부터 다시 실행하면 됩니다.

#### 기타 주의

- **세션은 휘발성**입니다. 새 세션마다 설치를 다시 해야 합니다(그래서 스크립트화).
- 전체(`requirements-full.txt`) 강제 설치는 Colab 기본 패키지를 깨뜨릴 수 있으니, 필요한
  top-level만 설치하는 걸 권장합니다.
- 플랫폼 한정 패키지(예: macOS 전용)는 Colab(Linux)에서 설치 실패하므로 추출 시 제외됩니다.
- `*_output.ipynb`(colab exec 실행 결과)와 `colab-sync/`(머신별 생성물)는 gitignore 처리됩니다.
