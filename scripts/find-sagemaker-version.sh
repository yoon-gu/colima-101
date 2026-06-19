#!/usr/bin/env sh
# Pod(SageMaker Distribution) 안에서 "이 Pod을 띄운 SageMaker 이미지 버전"을 찾는다.
# 쉘만 접근 가능할 때 Pod에 붙여넣고 실행하세요. 신뢰도 높은 소스부터 순서대로 출력합니다.
#
#   sh find-sagemaker-version.sh
#
# 해석 가이드:
#  - 가장 확실: ECR 이미지 URI 의 태그(예: .../sagemaker-distribution:2.2.0-cpu → SMD 2.2.0)
#  - 그 다음: 내부 메타데이터 JSON / 버전 파일 / 환경변수

echo "================ [1] 환경변수 (이미지 URI / 버전) ================"
env | grep -iE 'sagemaker|distribution|image.?uri|image.?arn|resource.?arn|^SMD' | sort
echo

echo "================ [2] SageMaker 내부 메타데이터 파일 ================"
for f in \
  /opt/.sagemakerinternal/internal-metadata.json \
  /opt/ml/metadata/resource-metadata.json \
  /etc/sagemaker-distribution/version \
  /opt/conda/sagemaker-distribution-version ; do
  if [ -f "$f" ]; then echo "--- $f ---"; cat "$f"; echo; fi
done
ls -la /opt/.sagemakerinternal/ 2>/dev/null
echo

echo "================ [3] 'sagemaker-distribution' 문자열을 담은 파일 ================"
grep -rliE 'sagemaker[-_]distribution' /opt /etc /usr/local 2>/dev/null | head -10
echo

echo "================ [4] 버전 흔적 파일 검색 ================"
find / -maxdepth 6 \( -iname '*sagemaker*version*' -o -iname '*distribution*version*' \) 2>/dev/null | head -10
find / -maxdepth 6 -ipath '*sagemaker*' -iname '*.json' 2>/dev/null | head -10
echo

echo "================ [5] conda 환경 (SMD는 conda 기반) ================"
conda info 2>/dev/null | grep -iE 'version|base environment|active env' || echo "(conda 없음)"
conda list 2>/dev/null | grep -iE 'sagemaker' | head
echo

echo "================ [6] (참고) SageMaker Python SDK 버전 — 이미지 버전과 다름! ================"
python -c "import sagemaker; print('sagemaker SDK', sagemaker.__version__)" 2>/dev/null || echo "(sagemaker SDK 없음)"
