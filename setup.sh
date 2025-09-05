#!/usr/bin/env bash
# r7525 (Clemson) bootstrap script
# - NVIDIA driver 535 + CUDA 11.8 (for V100S)
# - Miniconda (env: happy_zou, Python 3.10)
# - PyTorch 2.1.2 cu118 + common libs

set -euo pipefail

CUDA_VER="${CUDA_VER:-11.8}"
CUDA_PKG_VER="${CUDA_VER/./-}"    # 11.8 -> 11-8
NVIDIA_DRIVER="${NVIDIA_DRIVER:-535}"
CONDA_DIR=/opt/miniconda
ENV_NAME=happy_zou
PYVER=3.10

echo "[1/6] Base packages..."
apt-get update -y
apt-get install -y build-essential git curl wget tmux htop unzip p7zip-full \
  tree pkg-config cmake ca-certificates software-properties-common lsb-release \
  linux-headers-$(uname -r)

echo "[2/6] NVIDIA driver and CUDA ${CUDA_VER} ..."
cd /tmp
wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb
apt-get update -y
apt-get install -y "nvidia-driver-${NVIDIA_DRIVER}"
apt-get install -y "cuda-toolkit-${CUDA_PKG_VER}"

cat >/etc/profile.d/cuda.sh <<EOF
export CUDA_HOME=/usr/local/cuda-${CUDA_VER}
export PATH=\$CUDA_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$CUDA_HOME/lib64:\$LD_LIBRARY_PATH
EOF
chmod 644 /etc/profile.d/cuda.sh
# shellcheck disable=SC1091
source /etc/profile.d/cuda.sh || true

echo "[3/6] Miniconda ..."
if [ ! -d "$CONDA_DIR" ]; then
  wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
  bash /tmp/miniconda.sh -b -p "$CONDA_DIR"
  chown -R "$(id -u)":"$(id -g)" "$CONDA_DIR"
fi
eval "$($CONDA_DIR/bin/conda shell.bash hook)"
conda config --set auto_activate_base false

echo "[4/6] Conda env and PyTorch (cu118) ..."
if ! conda env list | grep -q "^${ENV_NAME}"; then
  conda create -y -n "${ENV_NAME}" python="${PYVER}" pip
fi
conda activate "${ENV_NAME}"
python -V
pip install --upgrade pip
pip install torch==2.1.2+cu118 torchvision==0.16.2+cu118 torchaudio==2.1.2+cu118 \
  --index-url https://download.pytorch.org/whl/cu118
pip install numpy scipy scikit-learn matplotlib pandas tqdm opencv-python \
            tensorboard pillow einops timm

echo "source ${CONDA_DIR}/bin/activate ${ENV_NAME}" >/etc/profile.d/conda_default_env.sh
chmod 644 /etc/profile.d/conda_default_env.sh

echo "[5/6] Verify stack ..."
set +e
nvidia-smi || true
nvcc --version || true
python - <<'PYCODE'
import torch
print("Torch:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())
print("CUDA (torch):", torch.version.cuda)
print("GPU count:", torch.cuda.device_count())
for i in range(torch.cuda.device_count()):
    print(i, torch.cuda.get_device_name(i))
PYCODE
set -e

echo "[6/6] Note on /data:"
echo "  - This profile requests a Blockstore mounted at /data."
echo "  - If /data is missing, check /etc/fstab and the instantiate logs."

echo "Done. Consider: sudo reboot"
