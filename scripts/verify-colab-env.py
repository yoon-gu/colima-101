# Colab 런타임에서 실행되어 핵심 라이브러리 버전을 출력한다(로컬과 비교용).
# colab exec -s <session> -f scripts/verify-colab-env.py 로 호출.
# 본인 스택에 맞게 PKGS 목록을 수정해서 쓰세요.
import sys
import importlib.metadata as md

PKGS = [
    "torch", "torchvision", "torchaudio",
    "transformers", "tokenizers", "huggingface-hub", "datasets", "accelerate",
    "numpy", "pydantic",
    "langchain", "langchain-core", "langchain-openai", "langchain-anthropic",
    "langgraph", "langgraph-checkpoint", "langsmith",
    "openai", "anthropic", "chromadb",
]

print("python", sys.version.split()[0])
try:
    import torch
    print("cuda available:", torch.cuda.is_available(),
          "| device:", (torch.cuda.get_device_name(0) if torch.cuda.is_available() else "CPU"))
except Exception:
    pass

for p in PKGS:
    try:
        print(f"  {p:22s} {md.version(p)}")
    except md.PackageNotFoundError:
        print(f"  {p:22s} (미설치)")
