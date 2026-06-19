# colima-101

Colima를 이용해 macOS에서 Docker와 Kubernetes(k3s)를 설치하고 테스트한 기록입니다.

## 환경

- **OS**: macOS (Apple Silicon, aarch64)
- **VM 백엔드**: macOS Virtualization.Framework
- **패키지 매니저**: Homebrew

## 설치한 구성요소

| 구성요소 | 버전 |
|---|---|
| Colima | 0.10.3 |
| Docker CLI | 29.6.0 (Server 29.5.2) |
| Kubernetes (k3s) | v1.35.0 |
| kubectl | 1.36.2 |

## 설치 과정

### 1. Homebrew로 설치

```bash
brew install colima docker kubectl
```

### 2. Colima 시작 (Kubernetes 활성화)

```bash
colima start --kubernetes
```

이 명령으로 Linux VM이 부팅되고, Docker 런타임과 k3s 기반 Kubernetes가 함께 프로비저닝됩니다.
kubectl 컨텍스트는 자동으로 `colima`로 설정됩니다.

## 테스트

### Docker

```bash
colima status
docker info
docker run --rm hello-world   # "Hello from Docker!" 출력 확인
```

### Kubernetes

```bash
kubectl config current-context   # colima
kubectl get nodes -o wide        # 노드 colima → Ready (control-plane)
kubectl get pods -A              # coredns, local-path-provisioner, metrics-server Running
```

실제 워크로드 배포 테스트:

```bash
kubectl create deployment nginx-test --image=nginx:alpine
kubectl wait --for=condition=available --timeout=120s deployment/nginx-test
kubectl get pods -l app=nginx-test -o wide

# 파드 내부에서 nginx 응답 확인
POD=$(kubectl get pod -l app=nginx-test -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$POD" -- wget -qO- http://localhost | grep -i "welcome to nginx"

# 정리
kubectl delete deployment nginx-test
```

→ nginx 파드가 정상적으로 Running 되고 "Welcome to nginx!" 응답을 확인하여 테스트 성공.

## 참고 명령어

### 리소스 조정

기본값은 CPU 2코어 / 메모리 약 2GiB입니다. 더 필요하면:

```bash
colima stop
colima start --kubernetes --cpu 4 --memory 8
```

### 라이프사이클

```bash
colima status            # 상태 확인
colima stop              # 중지
colima delete            # VM 완전 삭제
brew services start colima   # 로그인 시 자동 시작
```

---

## Pod 환경을 Docker 이미지로 재현하기

쉘에만 접근 가능한 Pod(예: SageMaker Distribution)의 환경을 최대한 비슷한 Docker
이미지로 복제하기 위한 도구 모음입니다. AI 개발 스택(HuggingFace / LangChain /
LangGraph)에 맞춰져 있습니다.

### 핵심 전략

`pip freeze` 전체를 베끼지 않습니다. SageMaker/conda 이미지의 freeze는 다수가
`@ file:///tmp/...` 로컬 휠이거나 환경 전용 패키지라 재현이 불가능합니다. 대신
**직접 import 하는 top-level 라이브러리만 정확한 버전으로 고정**하고 pip가 나머지
의존성을 풀게 합니다.

### 도구

| 파일 | 용도 |
|---|---|
| `scripts/collect-pod-env.sh` | Pod 안에서 전체 환경 정보 수집(OS·pip·conda·CUDA·시스템 패키지) → tar |
| `scripts/quick-summary.sh` | OS / Python / torch+CUDA / 핵심 라이브러리만 한 화면 요약(스크린샷용) |
| `scripts/key-versions.sh` | LangChain/LangGraph/HuggingFace 핵심 패키지 버전만 추출 |
| `requirements-pod.txt` | 위에서 확인한 top-level 라이브러리 정확 버전 고정 |
| `Dockerfile.sagemaker` | 자급식 재현 Dockerfile (CPU/GPU 빌드 인자 지원, 빌드 시 import 검증) |
| `Dockerfile.template` | 일반 재현용 주석 템플릿 |

### 절차

1. **Pod 안에서 정보 수집** (쉘만 되면 한 줄 복사/붙여넣기):
   ```sh
   sh quick-summary.sh   # 또는 key-versions.sh
   ```
   결과를 스크린샷으로 옮기는 게 손으로 재입력하는 것보다 효율적입니다.

2. **`requirements-pod.txt`** 의 버전을 확인한 값으로 맞춥니다.

3. **빌드 & 실행**:
   ```bash
   # 로컬 개발 (colima, arm64, CPU)
   docker build -f Dockerfile.sagemaker -t pod-clone:cpu .
   docker run --rm -it pod-clone:cpu python

   # GPU 클러스터 충실 재현 (x86_64 + CUDA 12.4)
   docker build --platform linux/amd64 --build-arg TORCH_INDEX=cu124 \
                -f Dockerfile.sagemaker -t pod-clone:gpu .
   docker run --rm -it --gpus all pod-clone:gpu python
   ```

### 현재 재현된 환경 (검증 완료)

Ubuntu 22.04 / Python 3.11 / torch 2.4.0(+cu124) / transformers 4.49.0 /
langchain 1.2.10 / langgraph 1.0.10 / chromadb 1.3.6 등. colima(GPU 없음)에서는
CPU torch로 빌드되어 `torch.cuda.is_available()`는 `False`이지만 버전은 동일합니다.

> ⚠️ 환경 전용·분산학습용 패키지는 외부에서 재현 불가라 제외했습니다. 그런 기능이
> 필요하면 실제 SMD 이미지를 베이스로 쓰세요.

---

## 내 로컬 패키지를 Colab에 맞추기 (google-colab-cli)

위 SageMaker 케이스가 "Pod → 로컬 이미지"였다면, 이건 반대 방향입니다.
**내 로컬 Python 패키지들을 원격 Colab 런타임에 설치해 Colab을 내 환경에 일치**시킵니다.
[google-colab-cli](https://github.com/googlecolab/google-colab-cli)(Google 공식)로 자동화합니다.

> 참고: Colab은 공식 Docker 이미지(`us-docker.pkg.dev/colab-images/public/runtime`)도
> 공개하므로, 반대로 "Colab 환경을 로컬에 가져오기"는 그 이미지를 pull 하면 됩니다.

### 설치 (최초 1회)

```bash
uv tool install google-colab-cli   # 또는: pip install google-colab-cli
```

첫 `colab` 명령 실행 시 브라우저로 Google OAuth 로그인이 뜹니다.

### 도구

| 파일 | 용도 |
|---|---|
| `scripts/freeze-local.sh` | 로컬 환경 → `colab-sync/requirements-{full,top}.txt` 추출(로컬경로·URL 라인 제외) |
| `scripts/freeze-from-image.sh` | **Docker 이미지** 안의 패키지 → `colab-sync/requirements-image.txt` 추출 |
| `scripts/colab-sync.sh` | `colab new → install -r → exec(검증)` 런북. 세션·requirements·GPU 인자 |
| `scripts/verify-colab-env.py` | Colab에서 실행돼 핵심 라이브러리 버전 출력(로컬과 비교) |
| `colab-pod-clone.ipynb` | pod-clone 패키지를 임베드한 자급식 노트북(Run all로 설치+검증) |
| `scripts/colab-run-notebook.sh` | 위 노트북을 colab-cli로 **CPU·T4 두 인스턴스**에서 실행 |

### 절차

```bash
# 1) 동기화할 환경의 패키지 추출 — 두 가지 출처 중 선택
#  (a) Docker 이미지에 맞추기 (예: 앞서 만든 pod-clone:cpu)  ← 권장
sh scripts/freeze-from-image.sh pod-clone:cpu
#  (b) 로컬 venv/conda에 맞추기
PYBIN=/path/to/venv/bin/python sh scripts/freeze-local.sh

# 2) Colab 세션 생성 + 설치 + 검증 (GPU는 선택: T4/L4/A100 등)
sh scripts/colab-sync.sh mysync colab-sync/requirements-image.txt T4

# 3) 끝나면 세션 정리
colab stop -s mysync
```

> **Python 버전**: 이미지/Pod는 3.11.9, Colab도 3.11 계열이라 패키지는 그대로 맞지만,
> 패치 버전(3.11.x)은 Colab이 정하므로 정확히 같게는 못 맞춥니다(패키지 호환엔 무방).

### 노트북을 colab-cli로 CPU·T4 양쪽에서 실행

`colab-pod-clone.ipynb`(131개 패키지 임베드, Run all로 설치+검증)를 두 인스턴스에서 자동 실행:

```bash
sh scripts/colab-run-notebook.sh        # CPU + T4 둘 다
sh scripts/colab-run-notebook.sh cpu    # CPU만
sh scripts/colab-run-notebook.sh t4     # T4 GPU만
```

각 인스턴스에서 `colab new → colab exec -f <노트북> --timeout 1800 → colab log → colab stop`
을 수행합니다. 설치가 오래 걸려 exec 타임아웃을 넉넉히 둡니다. GUI로 쓰려면 노트북을
Colab에서 열어 **Runtime → (Change runtime type) → Run all** 해도 됩니다.

### 주의

- **Colab 기본 환경엔 이미 버전이 고정된 torch/CUDA/numpy 등이 있습니다.** 전체
  `requirements-full.txt`를 강제 설치하면 Colab의 GPU용 torch가 깨질 수 있습니다.
  → 기본은 `requirements-top.txt`(top-level만) 권장, torch는 꼭 필요할 때만 핀.
- **세션은 휘발성**입니다. 새 세션마다 `colab install`을 다시 돌려야 합니다(그래서 스크립트화).
- google-colab-cli는 **본인 Colab 계정의 컴퓨트(쿼터/구독)** 를 사용합니다.
- 플랫폼 한정 패키지(예: macOS 전용)는 Colab(Linux)에서 설치 실패하므로 추출 시 제외합니다.
