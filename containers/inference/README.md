# inference 컨테이너 (운영 추론 job 편의용)

**운영(production)에서 추론 job을 편하게** 돌리기 위한 컨테이너를 재현합니다.
배포/서빙에 쓰는 환경과 동일하게 맞춰, 로컬·Colab에서 추론 job을 검증할 수 있게 합니다.

> 🚧 **상태: 작업 예정** — [issue #2](https://github.com/yoon-gu/colima-101/issues/2)

## dev 컨테이너와 차이

| | [`dev`](../dev/) | `inference` |
|---|---|---|
| 목적 | 개발 편의 | **운영 추론 job 편의** |
| 기준 환경 | SageMaker Distribution(개발) | 추론/서빙 환경 |
| 포함 | 개발용 전체 스택 | 추론에 필요한 최소 스택(+ 서빙 런타임) |

## TODO

- [ ] 운영 추론 job이 쓰는 베이스 이미지/런타임 확인 (SageMaker inference DLC, torchserve 등)
- [ ] 추론에 실제 필요한 패키지 목록화 (서빙/전처리/모델 로딩 의존성)
- [ ] `Dockerfile`, `requirements.txt`, (필요 시) `colab-*.ipynb` 추가
- [ ] 추론 job 동작 검증 (입력 → 추론 → 출력)

## 추가 시

[`../_template/`](../_template/) 를 복사해 시작하세요.
