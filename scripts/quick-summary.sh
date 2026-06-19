#!/usr/bin/env sh
# Pod 환경 "한 화면" 요약 — OS / Python / torch+CUDA / 핵심 AI 라이브러리 버전.
# collect-pod-env.sh 의 가벼운 버전. 손으로 옮기거나 스크린샷 찍기 좋게 최소 출력만 낸다.
#
# 사용법 (Pod 쉘에서):
#   sh quick-summary.sh
# 또는 파일 없이 한 줄로:
#   grep PRETTY /etc/os-release; python -V; \
#   python -c "import torch;print('torch',torch.__version__,torch.version.cuda)" 2>/dev/null; \
#   pip freeze | grep -iE 'torch|transformers|tokeniz|hugging|datasets|accel|langchain|langgraph|langs|openai|anthropic|pydantic|numpy|chromadb'

grep PRETTY /etc/os-release
python -V
python -c "import torch;print('torch',torch.__version__,torch.version.cuda)" 2>/dev/null || echo "torch: not installed"
pip freeze | grep -iE 'torch|transformers|tokeniz|hugging|datasets|accel|peft|bitsandbytes|sentence|langchain|langgraph|langs|openai|anthropic|pydantic|numpy|chromadb'
