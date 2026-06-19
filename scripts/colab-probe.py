import sys, subprocess
def sh(c):
    try:
        return subprocess.run(c, shell=True, capture_output=True, text=True).stdout.strip()
    except Exception as e:
        return str(e)
print('== /etc/os-release ==')
print(sh('cat /etc/os-release'))
print('== python ==', sys.version.split()[0])
print('== glibc ==', sh('ldd --version | head -1'))
print('== gcc ==', sh('gcc --version | head -1'))
print('== cuda toolkit ==', sh('ls -d /usr/local/cuda* 2>/dev/null; nvcc --version 2>/dev/null | tail -2'))
print('== nvidia ==', sh('nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || echo "no GPU (CPU runtime)"'))
print('== kernel ==', sh('uname -r'))
# cuDNN: 시스템 헤더 + 시스템 torch가 보는 버전
print('== cudnn header ==', sh(
    'for h in $(find / -name cudnn_version*.h 2>/dev/null | head -2); do '
    'echo $h; grep -E "#define CUDNN_(MAJOR|MINOR|PATCHLEVEL)" "$h"; done'))
print('== cudnn (system torch) ==', sh(
    'python3 -c "import torch;print(torch.__version__, \'cudnn\', torch.backends.cudnn.version())" 2>/dev/null '
    '|| echo "(system torch 없음)"'))
print('== libcudnn ==', sh('find / -name "libcudnn.so*" 2>/dev/null | head -3'))
