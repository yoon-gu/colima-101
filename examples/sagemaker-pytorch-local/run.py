"""
SageMaker PyTorch local mode 실행기 — estimator 인자가 컨테이너 경로로 어떻게 매핑되는지.

  entry_point="train.py", source_dir="src"
      → src/ 전체가 컨테이너 /opt/ml/code 로 올라가고, 거기서 train.py 실행
  fit(inputs={"train": "file://./data/train"})
      → ./data/train 이 컨테이너 /opt/ml/input/data/train 으로 들어감 (+ SM_CHANNEL_TRAIN)
  hyperparameters={"epochs": 3, "lr": 0.05}
      → train.py 에 --epochs 3 --lr 0.05 로 전달

  로컬 프로젝트 경로            →  컨테이너 안 경로
    src/train.py               →  /opt/ml/code/train.py
    data/train/data.csv        →  /opt/ml/input/data/train/data.csv
    (train.py가 모델 저장)     →  /opt/ml/model/   → SageMaker가 회수

실행:  python run.py     (사전 셋업은 README 참고)
"""
import os

os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")

from sagemaker.pytorch import PyTorch
from sagemaker.local import LocalSession

sess = LocalSession()
sess.config = {"local": {"local_code": True}}

# 공개 ECR 미러(익명 pull, 자격증명 불필요).
# 우리 Pod은 PyTorch 2.4.0이지만, 공개엔 2.5.1이 최근접이고 2.5↔2.4는 큰 차이 없다고 가정.
PUBLIC_DLC = "public.ecr.aws/deep-learning-containers/pytorch-training:2.5.1-cpu-py311-ubuntu22.04-sagemaker"

estimator = PyTorch(
    entry_point="train.py",     # src/ 안의 실행 스크립트 (컨테이너에선 /opt/ml/code/train.py)
    source_dir="src",           # 이 폴더 전체가 /opt/ml/code 로 올라감
    role="arn:aws:iam::000000000000:role/dummy",   # local mode는 role을 검증하지 않음(값만 필요)
    image_uri=PUBLIC_DLC,       # framework_version 대신 이미지를 직접 지정(자격증명 불필요)
    instance_type="local",      # CPU 로컬 (GPU면 "local_gpu" + NVIDIA 필요)
    instance_count=1,
    sagemaker_session=sess,
    hyperparameters={"epochs": 3, "lr": 0.05},
)

# 채널 이름 "train" → 컨테이너 /opt/ml/input/data/train, 그리고 SM_CHANNEL_TRAIN 환경변수
estimator.fit({"train": "file://./data/train"})
print(">>> 완료: 모델은 SageMaker가 model.tar.gz 로 회수했습니다")
