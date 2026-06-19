# colima-101

## 이 저장소의 목적 (왜 만들었나)

- 우리 코드는 **NVIDIA GPU가 달린 Ubuntu 컨테이너**(SageMaker)에서 돌아갑니다.
- 하지만 개발은 **Apple Silicon Mac(M5, 32GB)** 에서 합니다 — NVIDIA/CUDA가 없습니다.

**개발 순서**: ① **로컬 Docker 컨테이너**에서 원본과 동일한 환경을 만들어 GPU 없이(CPU) 코드를
확인 → ② 같은 코드를 **NVIDIA GPU로 테스트**하려고 **Colab T4** 사용.

이 저장소는 그렇게 재현하는 **여러 SageMaker 컨테이너를 계속 모아가는 곳**입니다.
(현재: `dev`. 예정: `inference` 등)

> 🔑 **왜 colima인가**: 로컬 Docker는 **Docker Desktop을 안 쓰고 colima(MIT 오픈소스)** 로
> 돌립니다. Docker Desktop은 일정 규모 이상 기업에서 **유료 라이선스**가 필요하지만, colima는
> 라이선스 부담 없이 동일한 `docker`/`kubectl` CLI를 그대로 씁니다. (저장소 이름이 `colima-101`인 이유)

## 저장소 구조

```
.
├── containers/                     # 컨테이너별 재현 정의 (각자 Dockerfile/requirements/notebook/README)
│   ├── README.md                   #   └ 컨테이너 목록 + 추가 가이드
│   ├── _template/                  #   └ 새 컨테이너 스캐폴드
│   ├── dev/                     #   └ ✅ 개발 편의용 — 우리 코드가 도는 Pod (Python 3.11.9 / torch 2.4.0+cu124)
│   └── inference/               #   └ 🚧 운영 추론 job 편의용 (작업 예정, #2)
├── scripts/                        # 공통 도구 (컨테이너 무관)
└── README.md                       # (이 파일) 목적 · 공통 워크플로우
```

→ 컨테이너 목록과 **새 컨테이너 추가하는 법**은 [`containers/README.md`](containers/README.md) 참고.

---

## TL;DR — 바로 돌리기

### 0) (최초 1회) colab-cli 설치 + 인증

```bash
uv tool install "git+https://github.com/googlecolab/google-colab-cli"  # PyPI보다 최신인 git 버전
colab --auth=oauth2 whoami    # 출력 URL을 브라우저로 승인 → 인증 코드 붙여넣기 → 계정 출력되면 OK
```
> `colab`은 `~/.local/bin/colab`에 깔립니다. 못 찾으면 PATH에 `~/.local/bin` 추가.

### 1) 컨테이너를 Colab T4(NVIDIA)에서 실행·검증

```bash
sh scripts/colab-run-notebook.sh t4     # 기본 = dev, GPU(T4)
sh scripts/colab-run-notebook.sh cpu    # GPU 없이 패키지만 확인
# 다른 컨테이너: NB=containers/<이름>/colab-*.ipynb sh scripts/colab-run-notebook.sh t4
```

### 2) 로컬 Docker 이미지로 재현 (colima, GPU 없이 CPU)

```bash
cd containers/dev
docker build -t dev:cpu .
docker run --rm -it dev:cpu python
```

> 컨테이너별 상세(확정 스택·검증·환경 비교·주의)는 각 폴더 README에 있습니다.
> 예: [`containers/dev/README.md`](containers/dev/README.md)

---

## 공통 워크플로우 (어떤 컨테이너든 동일)

### A. colima로 Docker + Kubernetes (로컬 토대)

**설치 버전**: Colima 0.10.3 · Docker CLI 29.6.0(Server 29.5.2) · Kubernetes(k3s) v1.35.0 · kubectl 1.36.2

```bash
brew install colima docker kubectl
colima start --kubernetes        # Docker 런타임 + k3s 함께 기동, kubectl 컨텍스트 자동 설정
```

검증(완료): `docker run --rm hello-world` · `kubectl get nodes` (colima Ready) ·
nginx 배포 → "Welcome to nginx!" 응답 확인. 라이프사이클: `colima status / stop / delete`,
리소스 조정 `colima start --kubernetes --cpu 4 --memory 8`.

### B. 원본 환경 수집 → Dockerfile 재현

**핵심 전략**: `pip freeze` 전체를 베끼지 않습니다. conda/SageMaker 이미지의 freeze는 다수가
`@ file:///tmp/...` 로컬 휠/환경 전용 패키지라 재현 불가입니다. 대신 **직접 import 하는
top-level 라이브러리만 정확한 버전으로 고정**하고 pip가 나머지를 풀게 합니다.

| 스크립트 | 용도 |
|---|---|
| `scripts/collect-pod-env.sh` | 컨테이너 쉘에서 전체 환경 정보 수집(OS·pip·conda·CUDA·시스템 패키지) → tar |
| `scripts/quick-summary.sh` | OS / Python / torch+CUDA / 핵심 라이브러리만 한 화면 요약(스크린샷용) |
| `scripts/key-versions.sh` | LangChain/LangGraph/HuggingFace 핵심 패키지 버전만 추출 |
| `scripts/freeze-from-image.sh` | Docker 이미지 안의 패키지 → Colab용 requirements 추출 |
| `scripts/freeze-local.sh` | 로컬 venv/conda 패키지 → requirements 추출 |

### C. Colab에 동기화 (google-colab-cli)

원본 패키지를 **원격 Colab 런타임에 설치해 Colab을 우리 환경에 맞춥니다.**
[google-colab-cli](https://github.com/googlecolab/google-colab-cli)(Google 공식)로 자동화.

| 스크립트 | 용도 |
|---|---|
| `scripts/colab-run-notebook.sh` | 컨테이너 노트북을 colab-cli로 CPU/T4 실행 (`NB=...`로 컨테이너 지정) |
| `scripts/colab-sync.sh` | `colab new → install -r → exec(검증)` 런북 (requirements 직접 지정) |
| `scripts/verify-colab-env.py` | Colab에서 핵심 라이브러리 버전 출력(비교용) |
| `scripts/colab-probe.py` | Colab 런타임 OS/CUDA/cuDNN/드라이버 조회(환경 비교용) |

핵심 주의(상세는 컨테이너 README): Colab 런타임 Python은 3.12라 `colab new`로는 버전 선택
불가 → **uv venv로 3.11.9를 별도 구성**. 세션은 휘발성이라 매 세션 설치 필요. colab-cli는
본인 Colab 컴퓨트(쿼터/구독)를 사용.

> 생성물(gitignore): `colab-sync/`(머신별 requirements), `*_output.ipynb`(colab exec 실행 결과).
