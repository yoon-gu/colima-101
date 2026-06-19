# SageMaker PyTorch local mode 예제 — 경로 잡는 법

"`train.py` 기준으로 데이터/모델 경로를 도대체 어떻게 만들어야 하나?"를 설명하는 예제입니다.
SageMaker가 컨테이너 안에 **고정 경로(컨트랙트)** 를 만들어주고, 우리는 그 경로를 **환경변수로** 받습니다.

## 핵심 — 로컬 경로 ↔ 컨테이너 경로 매핑

```
로컬 프로젝트                          컨테이너 안 (SageMaker가 만듦)         코드에서 받는 법
──────────────────────────────────────────────────────────────────────────────────────────
src/                          →   /opt/ml/code/            (entry_point 실행 위치)
  └ train.py                  →   /opt/ml/code/train.py
data/train/                   →   /opt/ml/input/data/train  ← env SM_CHANNEL_TRAIN
  └ data.csv                  →   /opt/ml/input/data/train/data.csv
hyperparameters={"epochs":3}  →   --epochs 3 (argparse 인자)  ← env SM_HP_EPOCHS
(train.py가 저장)             →   /opt/ml/model/            ← env SM_MODEL_DIR  → model.tar.gz 로 회수
```

규칙은 단순합니다:

| 무엇 | 어디서 받나 | 절대 |
|---|---|---|
| **입력 데이터** | `os.environ["SM_CHANNEL_<채널대문자>"]` (예: `SM_CHANNEL_TRAIN`) | 경로 하드코딩 ❌ |
| **모델 저장** | `os.environ["SM_MODEL_DIR"]` (= `/opt/ml/model`) | 여기 외에 저장하면 회수 안 됨 |
| **하이퍼파라미터** | argparse 인자 (`--epochs` …) | |

> 채널 이름이 곧 폴더/환경변수 이름이 됩니다. `fit({"train": ...})` → `/opt/ml/input/data/train`,
> `SM_CHANNEL_TRAIN`. `fit({"valid": ...})` 를 추가하면 `SM_CHANNEL_VALID` 가 생깁니다.

## 파일

```
examples/sagemaker-pytorch-local/
├── run.py              # estimator 정의 + fit (인자 → 컨테이너 경로 매핑을 주석으로 설명)
├── src/
│   └── train.py        # entry_point. SM_CHANNEL_TRAIN / SM_MODEL_DIR 로 경로 받는 표준 패턴
└── data/train/data.csv # file:// 채널 더미 데이터
```

`train.py`의 표준 패턴(이것만 외우면 됨):

```python
p.add_argument("--train",     default=os.environ.get("SM_CHANNEL_TRAIN", "/opt/ml/input/data/train"))
p.add_argument("--model-dir", default=os.environ.get("SM_MODEL_DIR",     "/opt/ml/model"))
...
files = os.listdir(args.train)                       # 데이터는 여기서 읽고
torch.save(model.state_dict(), f"{args.model_dir}/model.pth")  # 모델은 여기에 저장
```

## 실행

### 사전 셋업 (최초 1회)

```bash
# 1) sagemaker SDK (local mode는 2.x 에 있음) + docker compose
uv venv --python 3.11 .venv && uv pip install --python .venv/bin/python "sagemaker[local]<3"
brew install docker-compose && ln -sfn "$(brew --prefix)/opt/docker-compose/bin/docker-compose" ~/.docker/cli-plugins/docker-compose

# 2) colima: amd64 에뮬레이션 + 마운트 (DLC는 x86_64라 Apple Silicon에선 에뮬레이션)
docker run --privileged --rm tonistiigi/binfmt --install amd64
mkdir -p /private/tmp/smlocal
colima start --mount "$HOME:w" --mount /private/tmp/smlocal:w   # ← --mount는 기본 $HOME 마운트를 대체하므로 둘 다 명시
```

### 돌리기

```bash
cd examples/sagemaker-pytorch-local
export TMPDIR=/tmp/smlocal      # SageMaker local mode 임시폴더 (colima 마운트된 곳, /private prepend 유효)
python run.py
```

성공하면 컨테이너 로그에 경로들이 찍히고 `/opt/ml/model/model.pth` 가 저장됩니다.

## 메모

- **이미지**: 공개 ECR 미러(`public.ecr.aws/deep-learning-containers/pytorch-training:2.5.1-cpu-py311-ubuntu22.04-sagemaker`)
  를 써서 **AWS 자격증명 없이** 받습니다. 우리 Pod은 2.4.0이지만 공개엔 2.5.1이 최근접이고, 경로 학습엔 차이 없습니다.
- **GPU**: Apple Silicon Mac엔 NVIDIA가 없어 `instance_type="local"`(CPU)만. GPU는 `"local_gpu"` + 실제 NVIDIA 필요.
- **느림**: x86_64 DLC를 qemu로 에뮬레이션하므로 첫 pull(~7GB)·실행이 느립니다.
