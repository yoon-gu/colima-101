"""
SageMaker PyTorch 학습 스크립트 예제 — "경로가 도대체 어떻게 잡히는지" 이해용.

[핵심] 컨테이너 안에서 SageMaker가 만들어주는 고정 경로(컨트랙트):

    /opt/ml/input/data/<채널명>                ← fit(inputs={"<채널명>": ...}) 로 넣은 데이터
    /opt/ml/input/config/hyperparameters.json  ← 하이퍼파라미터 (스크립트엔 --key value 로 전달됨)
    /opt/ml/code/                              ← source_dir 내용 (이 train.py가 여기서 실행됨)
    /opt/ml/model/                             ← 학습된 모델을 *여기에 저장*해야 SageMaker가 회수
    /opt/ml/output/data/                       ← 모델 외 추가 산출물(로그/지표 등)

★ 절대 경로를 하드코딩하지 말고 환경변수를 쓴다 (SageMaker가 채워줌):
    SM_CHANNEL_<채널대문자>  = 그 채널 데이터 경로   (예: SM_CHANNEL_TRAIN = /opt/ml/input/data/train)
    SM_MODEL_DIR             = 모델 저장 경로        (= /opt/ml/model)
    SM_OUTPUT_DATA_DIR       = 추가 산출물 경로      (= /opt/ml/output/data)
  하이퍼파라미터는 argparse 인자로 들어온다 (--epochs 3 --lr 0.05 ...).
"""
import argparse
import os

import torch
import torch.nn as nn


def parse_args():
    p = argparse.ArgumentParser()
    # 1) 하이퍼파라미터: estimator(hyperparameters={...}) → "--key value" 로 들어온다
    p.add_argument("--epochs", type=int, default=1)
    p.add_argument("--lr", type=float, default=0.01)
    # 2) 경로: 기본값을 SM_* 환경변수로 둔다 (컨테이너 밖에서 직접 돌릴 때도 동작하도록 fallback)
    p.add_argument("--train", type=str, default=os.environ.get("SM_CHANNEL_TRAIN", "/opt/ml/input/data/train"))
    p.add_argument("--model-dir", type=str, default=os.environ.get("SM_MODEL_DIR", "/opt/ml/model"))
    return p.parse_args()


def main():
    args = parse_args()

    # ---------- (교육용) SageMaker가 잡아준 경로/환경 출력 ----------
    print("=" * 64)
    print("torch", torch.__version__, "| cuda?", torch.cuda.is_available())
    print("[code ] 이 스크립트 위치  :", os.path.dirname(os.path.abspath(__file__)))   # → /opt/ml/code
    print("[train] 데이터 채널 경로  :", args.train)                                    # → /opt/ml/input/data/train
    print("[model] 모델 저장 경로    :", args.model_dir)                                # → /opt/ml/model
    print("[hp   ] epochs / lr      :", args.epochs, args.lr)
    print("[env  ] SM_CHANNEL_*     :", {k: v for k, v in os.environ.items() if k.startswith("SM_CHANNEL")})
    print("=" * 64)

    # ---------- 데이터 읽기: 하드코딩(X) → args.train(=SM_CHANNEL_TRAIN)(O) ----------
    print("[train] 채널 안 파일들:", os.listdir(args.train))
    data_path = os.path.join(args.train, "data.csv")
    rows = open(data_path).read().strip().splitlines() if os.path.exists(data_path) else []
    print(f"[train] {data_path} → {len(rows)} 줄 읽음")

    # ---------- 아주 단순한 "학습" ----------
    model = nn.Linear(2, 1)
    opt = torch.optim.SGD(model.parameters(), lr=args.lr)
    for e in range(args.epochs):
        x = torch.randn(8, 2)
        y = x.sum(dim=1, keepdim=True)            # y = x1 + x2 를 배우게 함
        loss = ((model(x) - y) ** 2).mean()
        opt.zero_grad()
        loss.backward()
        opt.step()
        print(f"[train] epoch {e + 1}/{args.epochs}  loss={loss.item():.4f}")

    # ---------- 모델 저장: 반드시 args.model_dir(=/opt/ml/model) 에! ----------
    os.makedirs(args.model_dir, exist_ok=True)
    out = os.path.join(args.model_dir, "model.pth")
    torch.save(model.state_dict(), out)
    print("[model] 저장 완료 →", out)
    print("        (SageMaker가 이 폴더를 model.tar.gz 로 묶어 회수한다)")


if __name__ == "__main__":
    main()
