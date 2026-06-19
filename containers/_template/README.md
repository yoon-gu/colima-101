# <컨테이너 이름> 컨테이너

(한 줄 설명: 어떤 원본 컨테이너/Pod를 재현하는가)

## 확정 스택

| 항목 | 값 |
|---|---|
| OS | |
| Python | |
| torch / CUDA | |
| 핵심 패키지 | |

## 구성

| 파일 | 용도 |
|---|---|
| `Dockerfile` | 재현 Dockerfile |
| `requirements.txt` | top-level 라이브러리 버전 고정 |
| `colab-*.ipynb` | Colab 실행/검증 노트북 (선택) |

## 빌드 & 실행

```bash
cd containers/<이름>
docker build -t <이름>:cpu .
docker run --rm -it <이름>:cpu python
```

## Colab 검증 (선택)

```bash
NB=containers/<이름>/colab-*.ipynb sh scripts/colab-run-notebook.sh t4
```

## 주의 / 한계

-
