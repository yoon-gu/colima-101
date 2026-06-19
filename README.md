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
