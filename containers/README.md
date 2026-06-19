# containers/

원본(SageMaker 등) 컨테이너를 재현하는 정의를 **컨테이너별 폴더**로 모읍니다.
각 폴더는 자체 `Dockerfile` / `requirements.txt` / `colab-*.ipynb` / `README.md`를 갖습니다.

## 컨테이너 목록

| 컨테이너 | 설명 | 상태 |
|---|---|---|
| [`dev/`](dev/) | **개발 편의용** — SageMaker Distribution(Studio/개발) Pod 재현. Python 3.11.9 / torch 2.4.0+cu124 | ✅ 검증 완료 |
| [`inference/`](inference/) | **운영 추론 job 편의용** — 추론/서빙 환경 재현 | 🚧 작업 예정 ([#2](https://github.com/yoon-gu/colima-101/issues/2)) |

## 새 컨테이너 추가하는 법

1. [`_template/`](_template/) 를 복사: `cp -r containers/_template containers/<이름>`
2. 원본 환경 정보를 수집 (저장소 루트의 공통 스크립트):
   - Pod 쉘에서 `sh scripts/quick-summary.sh` / `key-versions.sh`
   - 또는 이미 만든 이미지에서 `sh scripts/freeze-from-image.sh <image>`
3. `Dockerfile` / `requirements.txt` 를 채우고, 필요하면 `colab-*.ipynb` 추가
4. `<이름>/README.md` 작성, [목록](#컨테이너-목록)에 한 줄 추가

> 공통 도구(`scripts/`)는 컨테이너에 무관하게 재사용합니다 — [최상위 README](../README.md) 참고.
