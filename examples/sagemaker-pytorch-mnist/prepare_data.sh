#!/usr/bin/env sh
# 공식 MNIST 예제용 데이터 준비: MNIST 받아서 소규모 subset(train 3000/test 1000)으로 잘라
# data/MNIST/raw/ 에 둔다. (공식 mnist.py 는 다운로드하지 않고 채널에서 읽으므로 미리 준비 필요)
set -e
cd "$(dirname "$0")"
RAW=data/MNIST/raw
mkdir -p "$RAW"; cd "$RAW"
BASE=https://ossci-datasets.s3.amazonaws.com/mnist     # PyTorch 공식 MNIST 미러
for f in train-images-idx3-ubyte train-labels-idx1-ubyte t10k-images-idx3-ubyte t10k-labels-idx1-ubyte; do
  curl -fsSL "$BASE/$f.gz" -o "$f.gz" && gunzip -kf "$f.gz"
done
python3 - <<'PY'
import struct, os
def ti(p,n):  # truncate images
    f=open(p,'rb'); m,c,r,col=struct.unpack('>IIII',f.read(16)); d=f.read(n*r*col); f.close()
    open(p,'wb').write(struct.pack('>IIII',m,n,r,col)+d)
def tl(p,n):  # truncate labels
    f=open(p,'rb'); m,c=struct.unpack('>II',f.read(8)); d=f.read(n); f.close()
    open(p,'wb').write(struct.pack('>II',m,n)+d)
ti('train-images-idx3-ubyte',3000); tl('train-labels-idx1-ubyte',3000)
ti('t10k-images-idx3-ubyte',1000);  tl('t10k-labels-idx1-ubyte',1000)
for f in os.listdir('.'):
    if f.endswith('.gz'): os.remove(f)
print("준비 완료: data/MNIST/raw (train 3000 / test 1000)")
PY
