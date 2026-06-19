# SageMaker 공식 PyTorch MNIST 예제 (colima local mode)

AWS 공식 예제 [amazon-sagemaker-examples / pytorch_mnist](https://github.com/aws/amazon-sagemaker-examples/tree/main/sagemaker-python-sdk/pytorch_mnist)
의 학습 스크립트(`src/mnist.py`)를 **그대로** colima local mode 로 돌립니다.

- `src/mnist.py` — 공식 스크립트(수정 없음). 채널명은 **`training`**(= `SM_CHANNEL_TRAINING`).
- 빠르게 보려고 데이터는 소규모 subset(train 3000 / test 1000), `epochs=1` 로 실행.
- 공개 DLC(`...pytorch-training:2.5.1-cpu-py311-...`)라 **AWS 자격증명 불필요**.

> 경로(데이터/모델)가 어떻게 잡히는지 자체가 궁금하면 먼저
> [`../sagemaker-pytorch-local/`](../sagemaker-pytorch-local/) 예제를 보세요. 여기는 "공식 예제를 그대로 돌려보기"입니다.

## 실행

```bash
# 0) (최초 1회) colima/sagemaker 셋업은 ../sagemaker-pytorch-local/README.md 참고
#    (sagemaker[local]<3, docker-compose, binfmt amd64, colima --mount $HOME + /private/tmp/smlocal)

cd examples/sagemaker-pytorch-mnist
sh prepare_data.sh                  # MNIST 받아서 subset 으로 data/MNIST/raw 준비
export TMPDIR=/tmp/smlocal
python run.py
```

## 결과 (실측)

```
... Train Epoch: 1 ...
Test set: Average loss: 2.29, Accuracy: 141/1000 (14%)
Saving the model.
Reporting training SUCCESS  · exited with code 0
```

정확도가 낮은 건 정상입니다 — **subset 3000장 + 1 epoch**이라 그렇습니다. 제대로 학습하려면
`run.py`의 `hyperparameters`에서 `epochs`를 키우고 `prepare_data.sh`의 subset 크기를 늘리세요
(전체 60000장 1 epoch도 가능하나 x86_64 DLC를 에뮬레이션하므로 느립니다).

## 메모

- `data/`(MNIST 바이너리)는 `.gitignore` 처리 — `prepare_data.sh`로 재생성합니다.
- GPU(`local_gpu`)는 Apple Silicon에 NVIDIA가 없어 불가 → CPU(`local`)만.
