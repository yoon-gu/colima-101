"""
SageMaker 공식 PyTorch MNIST 예제 (amazon-sagemaker-examples) 를 colima local mode 로 실행.

- src/mnist.py 는 공식 학습 스크립트 그대로(채널명 "training" = SM_CHANNEL_TRAINING).
- 빠르게 보려고 데이터는 소규모 subset(train 3000/test 1000), epochs=1 로 돌린다.
- 공개 DLC(2.5.1, 익명 pull)로 AWS 자격증명 없이 실행.

실행:  python run.py   (사전 셋업은 ../sagemaker-pytorch-local/README.md 참고)
"""
import os

os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")

from sagemaker.pytorch import PyTorch
from sagemaker.local import LocalSession

sess = LocalSession()
sess.config = {"local": {"local_code": True}}

PUBLIC_DLC = "public.ecr.aws/deep-learning-containers/pytorch-training:2.5.1-cpu-py311-ubuntu22.04-sagemaker"

estimator = PyTorch(
    entry_point="mnist.py",      # 공식 스크립트
    source_dir="src",
    role="arn:aws:iam::000000000000:role/dummy",
    image_uri=PUBLIC_DLC,
    instance_type="local",       # CPU
    instance_count=1,
    sagemaker_session=sess,
    hyperparameters={"epochs": 1, "batch-size": 256, "backend": "gloo"},
)

# 채널 이름 "training" → /opt/ml/input/data/training (mnist.py 의 SM_CHANNEL_TRAINING)
# ./data 안에 MNIST/raw/... 가 있어야 함
estimator.fit({"training": "file://./data"})
print(">>> 완료")
