#!/usr/bin/env bash
#
# carrotpilot PC (Q5 MLB) 一键安装+编译脚本
# 适用于 Ubuntu 22.04/24.04 + NVIDIA GPU (CUDA)
#
# 用法:
#   git clone -b q5-mlb git@github.com:dingxinyi123/carrotpilot.git
#   cd carrotpilot
#   bash tools/pc_setup.sh
#
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
ROOT="$DIR/.."
cd "$ROOT"

echo -e "${BOLD}=== carrotpilot PC Setup (Q5 MLB) ===${NC}"
echo "工作目录: $(pwd)"
echo ""

# ============================================================
# 第1步: 系统依赖
# ============================================================
echo -e "${BOLD}[1/6] 安装系统依赖...${NC}"

SUDO=""
if [[ $(id -u) -ne 0 ]]; then
  SUDO="sudo"
fi

$SUDO apt-get update
$SUDO apt-get install -y --no-install-recommends \
  ca-certificates \
  clang \
  build-essential \
  gcc-arm-none-eabi \
  liblzma-dev \
  capnproto \
  libcapnp-dev \
  curl \
  libcurl4-openssl-dev \
  git \
  git-lfs \
  ffmpeg \
  libavformat-dev \
  libavcodec-dev \
  libavdevice-dev \
  libavutil-dev \
  libavfilter-dev \
  libbz2-dev \
  libeigen3-dev \
  libffi-dev \
  libglew-dev \
  libgles2-mesa-dev \
  libglfw3-dev \
  libglib2.0-0 \
  libjpeg-dev \
  libqt5charts5-dev \
  libncurses5-dev \
  libssl-dev \
  libusb-1.0-0-dev \
  libzmq3-dev \
  libzstd-dev \
  libsqlite3-dev \
  libsystemd-dev \
  locales \
  opencl-headers \
  ocl-icd-libopencl1 \
  ocl-icd-opencl-dev \
  portaudio19-dev \
  qtlocation5-dev \
  qtpositioning5-dev \
  qttools5-dev-tools \
  libqt5svg5-dev \
  libqt5serialbus5-dev \
  libqt5x11extras5-dev \
  libqt5opengl5-dev \
  g++-12 \
  qtbase5-dev \
  qtchooser \
  qt5-qmake \
  qtbase5-dev-tools \
  python3-dev \
  python3-venv

# NVIDIA CUDA (tinygrad 需要)
if ! command -v nvcc &> /dev/null; then
  echo -e "${RED}未检测到 CUDA toolkit，请先安装 NVIDIA 驱动和 nvidia-cuda-toolkit${NC}"
  echo "  sudo apt install nvidia-driver-550 nvidia-cuda-toolkit"
  exit 1
else
  echo -e " ${GREEN}✔${NC} CUDA: $(nvcc --version | tail -1)"
fi

# GPU 检测
if command -v nvidia-smi &> /dev/null; then
  GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "unknown")
  echo -e " ${GREEN}✔${NC} GPU: $GPU"
else
  echo -e "${RED}未检测到 NVIDIA GPU${NC}"
  exit 1
fi

echo -e " ${GREEN}✔${NC} 系统依赖安装完成"

# ============================================================
# 第2步: panda/jungle udev 规则
# ============================================================
echo -e "\n${BOLD}[2/6] 配置 USB 权限 (panda udev)...${NC}"

if [[ -d "/etc/udev/rules.d/" ]]; then
  $SUDO tee /etc/udev/rules.d/11-panda.rules > /dev/null <<EOF
SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="3801", ATTRS{idProduct}=="ddcc", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="3801", ATTRS{idProduct}=="ddee", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="bbaa", ATTRS{idProduct}=="ddcc", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="bbaa", ATTRS{idProduct}=="ddee", MODE="0666"
EOF

  $SUDO tee /etc/udev/rules.d/12-panda_jungle.rules > /dev/null <<EOF
SUBSYSTEM=="usb", ATTRS{idVendor}=="3801", ATTRS{idProduct}=="ddcf", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="3801", ATTRS{idProduct}=="ddef", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="bbaa", ATTRS{idProduct}=="ddcf", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="bbaa", ATTRS{idProduct}=="ddef", MODE="0666"
EOF

  $SUDO udevadm control --reload-rules && $SUDO udevadm trigger || true
  echo -e " ${GREEN}✔${NC} udev 规则已配置"
fi

# ============================================================
# 第3步: Python 虚拟环境 + 依赖
# ============================================================
echo -e "\n${BOLD}[3/6] 安装 Python 依赖 (uv)...${NC}"

if ! command -v uv &> /dev/null; then
  echo "安装 uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

uv self update || true
uv sync --frozen --all-extras
source .venv/bin/activate

echo "PYTHONPATH=${PWD}" > .env
echo -e " ${GREEN}✔${NC} Python 虚拟环境就绪"

# ============================================================
# 第4步: 编译 opendbc (CAN parser)
# ============================================================
echo -e "\n${BOLD}[4/6] 编译 opendbc CAN parser...${NC}"

PYTHONPATH="$(pwd)/tinygrad_repo" PATH="$(pwd)/.venv/bin:$PATH" \
  .venv/bin/scons -j$(nproc) opendbc_repo/opendbc/can/

echo -e " ${GREEN}✔${NC} opendbc 编译完成"

# ============================================================
# 第5步: 编译 pandad
# ============================================================
echo -e "\n${BOLD}[5/6] 编译 pandad...${NC}"

PYTHONPATH="$(pwd)/tinygrad_repo" PATH="$(pwd)/.venv/bin:$PATH" \
  .venv/bin/scons -j$(nproc) selfdrive/pandad/pandad

echo -e " ${GREEN}✔${NC} pandad 编译完成"

# ============================================================
# 第6步: 编译模型 + UI (完整 scons)
# ============================================================
echo -e "\n${BOLD}[6/6] 编译 modeld / UI / 其余组件...${NC}"

PYTHONPATH="$(pwd)/tinygrad_repo" PATH="$(pwd)/.venv/bin:$PATH" \
  .venv/bin/scons -j$(nproc)

echo -e " ${GREEN}✔${NC} 全部编译完成"

# ============================================================
# 完成
# ============================================================
echo ""
echo -e "${BOLD}${GREEN}=== 安装完成! ===${NC}"
echo ""
echo "运行方法:"
echo "  cd $(pwd)"
echo "  source .venv/bin/activate"
echo "  export PYTHONPATH=$(pwd)/tinygrad_repo:\$(pwd)"
echo ""
echo "  # PC 模式启动 (webcam + panda USB)"
echo "  USE_WEBCAM=1 python selfdrive/manager/manager.py"
echo ""
echo "注意事项:"
echo "  - 首次运行 modeld 会用 tinygrad 编译 CUDA kernel，需要几分钟"
echo "  - 确保摄像头已连接 (/dev/video0)"
echo "  - 确保 panda 已连接 USB"
