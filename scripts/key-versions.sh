#!/usr/bin/env sh
# LangChain/LangGraph/HuggingFace 핵심 패키지 버전만 콕 집어 추출.
# requirements-pod.txt 의 top-level 핀을 갱신할 때 이 출력을 그대로 쓰면 된다.
#
# 사용법 (Pod 쉘에서):
#   sh key-versions.sh
# 또는 한 줄로:
#   pip freeze | grep -iE 'langchain|langgraph|langsmith|^transformers|tokenizers|sentence-transformers|huggingface-hub|datasets|accelerate'

pip freeze | grep -iE 'langchain|langgraph|langsmith|^transformers|tokenizers|sentence-transformers|huggingface-hub|datasets|accelerate'
