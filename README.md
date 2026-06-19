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
