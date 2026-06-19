# inference 컨테이너 (운영 추론 job 편의용)

**운영(production)에서 추론 job을 편하게** 돌리기 위한 컨테이너를 재현합니다.
배포/서빙에 쓰는 환경과 동일하게 맞춰, 로컬·Colab에서 추론 job을 검증할 수 있게 합니다.

> 🚧 **상태: 작업 예정** — [issue #2](https://github.com/yoon-gu/colima-101/issues/2)

## dev 컨테이너와 차이

| | [`dev`](../dev/) | `inference` |
|---|---|---|
| 목적 | 개발 편의 | **운영 추론 job 편의** |
| 기준 환경 | SageMaker Distribution(개발) | 추론/서빙 환경 |
| 포함 | 개발용 전체 스택 | 추론에 필요한 최소 스택(+ 서빙 런타임) |

## 참고: SageMaker local mode vs training/inference container

둘은 대립 개념이 아니라 **축이 다릅니다** — "무엇을 돌리느냐" vs "어디서/어떻게 돌리느냐".

- **컨테이너** = *무엇*. 추론/학습 코드를 실제로 실행하는 **Docker 이미지**(AWS DLC 또는 커스텀).
  안에 프레임워크 + `sagemaker-*` 툴킷이 있어 SageMaker 규약(채널·`/opt/ml/model` 등)대로 동작.
  클라우드든 로컬이든 **돌아가는 이미지 자체**.
- **Local mode** = *어디서/어떻게*. SageMaker **Python SDK** 기능. `instance_type='local'`(또는
  `'local_gpu'`)을 주면 관리형 클라우드 대신 **내 로컬 Docker에서 그 컨테이너를 그대로 띄워**
  job 흐름을 에뮬레이트. → **local mode가 컨테이너를 (로컬에서) 실행**한다.

| | Local mode | 컨테이너 |
|---|---|---|
| 정체 | SDK 실행 방식(오케스트레이션) | 실행되는 이미지 |
| 어디서 | 내 로컬 Docker (**colima OK**) | 클라우드/로컬 어디서나 |
| 목적 | 빠른 반복·디버깅, 비용 0 | 실제 런타임 제공 |
| 한계 | 단일 머신, 내 하드웨어, 멀티노드 분산 X | — |

**우리 셋업과의 연결**:
- local mode의 Docker 백엔드로 **colima 그대로 사용 가능**(Docker Desktop 불필요 — 라이선스 회피 유지).
  SDK가 내부적으로 docker compose를 쓰고 colima가 docker 엔진을 제공.
- 단 동일한 한계: M-series Mac엔 NVIDIA가 없어 `local_gpu` 불가 → **CPU만**. GPU 검증은 **Colab T4**.
  또 DLC는 x86_64라 arm64 Mac에선 에뮬레이션(느림).
- 손으로 Dockerfile 재현(이 폴더 방식)과 **local mode로 실제 DLC 실행**은 보완재 —
  후자가 "진짜 이미지를 그대로 쓴다"는 점에서 더 충실(단 GPU는 여전히 Colab).

> DLC 이미지 **태그가 곧 스택 명세**입니다. 예:
> `pytorch-inference:2.4.0-gpu-py311-cu124-ubuntu22.04-sagemaker` → torch 2.4.0 / py3.11 / cu124 / ubuntu22.04.

## TODO

- [ ] **DLC가 Pod 베이스와 일치하는지 대조** — `IMAGE=...pytorch-inference:... sh scripts/compare-dlc.sh`
      (dev Pod 베이스는 `pytorch-training:2.4.0-gpu-py311-cu124-ubuntu22.04-sagemaker` 로 확인됨, [#2](https://github.com/yoon-gu/colima-101/issues/2))
- [ ] **local mode + colima로 실제 추론 DLC 실행** 검토 (SDK `instance_type='local'`)

- [ ] 운영 추론 job이 쓰는 베이스 이미지/런타임 확인 (SageMaker inference DLC, torchserve 등)
- [ ] 추론에 실제 필요한 패키지 목록화 (서빙/전처리/모델 로딩 의존성)
- [ ] `Dockerfile`, `requirements.txt`, (필요 시) `colab-*.ipynb` 추가
- [ ] 추론 job 동작 검증 (입력 → 추론 → 출력)

## 추가 시

[`../_template/`](../_template/) 를 복사해 시작하세요.
