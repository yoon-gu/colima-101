# sagemaker-training 컨테이너 (작업 예정)

SageMaker **training container**(DLC) 기준으로 학습 환경을 재현합니다.
`sagemaker-distribution`에서 제외했던 학습 전용 컴포넌트를 다룹니다.

> 🚧 **상태: 작업 예정** — [issue #2](https://github.com/yoon-gu/colima-101/issues/2)

## 왜 별도 컨테이너인가

`sagemaker-distribution`(추론/개발 환경)에서는 아래 학습 전용 패키지를 **외부 재현 불가**라
제외했습니다. 실제 학습 워크로드(특히 분산학습)에서는 이들이 필요합니다.

- `sagemaker_pytorch_training`
- `smdistributed-dataparallel` (SMDDP)
- `apex` (NVIDIA, 소스 빌드 → nvcc + 호환 gcc 필요)
- `smprof`, `s3torchconnector` 등

## TODO

- [ ] 우리가 쓰는 training DLC 이미지 태그/버전 확인
- [ ] 학습에 실제 필요한 패키지 목록화
- [ ] 공식 SageMaker DLC 베이스로 재현 방안 검토
- [ ] 분산학습(SMDDP)·apex 소스 빌드 시 nvcc/gcc 정합 검토
- [ ] `Dockerfile`, `requirements.txt`, `colab-*.ipynb` 추가

## 추가 시

[`../_template/`](../_template/) 를 복사해 시작하세요.
