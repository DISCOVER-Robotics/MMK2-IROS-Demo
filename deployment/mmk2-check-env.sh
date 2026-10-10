#!/bin/bash
# MMK2 IROS Demo 目标机器环境检查脚本
# 在目标机器上运行此脚本，确认是否满足部署条件

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "${GREEN}✓${NC} $*"; ((PASS++)); }
fail() { echo -e "${RED}✗${NC} $*"; ((FAIL++)); }
warn() { echo -e "${YELLOW}⚠${NC} $*"; ((WARN++)); }
info() { echo -e "${BLUE}ℹ${NC} $*"; }

echo "========================================"
echo "MMK2 IROS Demo 环境检查"
echo "========================================"
echo

# ============ 1. 系统信息 ============
echo "【1】系统信息"
if [[ -f /etc/os-release ]]; then
    OS_NAME=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
    info "操作系统: ${OS_NAME}"
else
    warn "无法读取系统信息"
fi

KERNEL=$(uname -r)
info "内核版本: ${KERNEL}"

ARCH=$(uname -m)
if [[ "${ARCH}" == "x86_64" ]]; then
    pass "架构: ${ARCH}"
else
    fail "架构: ${ARCH} (需要 x86_64)"
fi
echo

# ============ 2. 硬件资源 ============
echo "【2】硬件资源"

# CPU 核心数
CPU_CORES=$(nproc)
if [[ ${CPU_CORES} -ge 8 ]]; then
    pass "CPU 核心: ${CPU_CORES}"
else
    warn "CPU 核心: ${CPU_CORES} (推荐 >= 8)"
fi

# 内存
TOTAL_MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
if [[ ${TOTAL_MEM_GB} -ge 16 ]]; then
    pass "总内存: ${TOTAL_MEM_GB} GB"
else
    warn "总内存: ${TOTAL_MEM_GB} GB (推荐 >= 16 GB)"
fi

# 可用内存
AVAIL_MEM_GB=$(free -g | awk '/^Mem:/{print $7}')
info "可用内存: ${AVAIL_MEM_GB} GB"

# 磁盘空间
DISK_AVAIL_GB=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
if [[ ${DISK_AVAIL_GB} -ge 40 ]]; then
    pass "根分区可用: ${DISK_AVAIL_GB} GB"
else
    fail "根分区可用: ${DISK_AVAIL_GB} GB (需要 >= 40 GB)"
fi
echo

# ============ 3. NVIDIA GPU ============
echo "【3】NVIDIA GPU"

if command -v nvidia-smi &> /dev/null; then
    pass "nvidia-smi 已安装"

    # GPU 型号
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
    info "GPU 型号: ${GPU_NAME}"

    # 驱动版本
    DRIVER_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
    DRIVER_MAJOR=$(echo "${DRIVER_VER}" | cut -d. -f1)

    if [[ ${DRIVER_MAJOR} -ge 570 ]]; then
        pass "驱动版本: ${DRIVER_VER} (>= 570.x)"
    elif [[ ${DRIVER_MAJOR} -ge 535 ]]; then
        warn "驱动版本: ${DRIVER_VER} (可用，但推荐 >= 570.x)"
    else
        fail "驱动版本: ${DRIVER_VER} (需要 >= 535.x)"
    fi

    # CUDA 版本
    CUDA_VER=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1)
    info "计算能力: ${CUDA_VER}"

    # 显存
    GPU_MEM_GB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | awk '{print int($1/1024)}')
    if [[ ${GPU_MEM_GB} -ge 12 ]]; then
        pass "显存: ${GPU_MEM_GB} GB"
    elif [[ ${GPU_MEM_GB} -ge 6 ]]; then
        warn "显存: ${GPU_MEM_GB} GB (可用，推荐 >= 12 GB)"
    else
        fail "显存: ${GPU_MEM_GB} GB (需要 >= 6 GB)"
    fi

    # GPU 架构推断
    if echo "${GPU_NAME}" | grep -qiE "RTX (30|40)|A[0-9]{3,4}|L[0-9]{1,2}|H100"; then
        pass "GPU 架构: Ampere/Ada/Hopper (推荐)"
    elif echo "${GPU_NAME}" | grep -qiE "RTX 20|GTX 16|T4"; then
        warn "GPU 架构: Turing (可能兼容，但未充分测试)"
    else
        warn "GPU 架构: 未知 (请确认兼容性)"
    fi
else
    fail "nvidia-smi 未找到 (请安装 NVIDIA 驱动)"
fi
echo

# ============ 4. Docker ============
echo "【4】Docker"

if command -v docker &> /dev/null; then
    pass "Docker 已安装"

    DOCKER_VER=$(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)
    DOCKER_MAJOR=$(echo "${DOCKER_VER}" | cut -d. -f1)

    if [[ ${DOCKER_MAJOR} -ge 20 ]]; then
        pass "Docker 版本: ${DOCKER_VER}"
    else
        warn "Docker 版本: ${DOCKER_VER} (推荐 >= 20.10)"
    fi

    # 检查 Docker 服务
    if docker info &> /dev/null; then
        pass "Docker 服务正常"
    else
        fail "Docker 服务异常 (可能需要 sudo 或加入 docker 组)"
    fi
else
    fail "Docker 未安装"
fi
echo

# ============ 5. NVIDIA Container Toolkit ============
echo "【5】NVIDIA Container Toolkit"

if command -v docker &> /dev/null && docker info 2>/dev/null | grep -qi nvidia; then
    pass "NVIDIA Container Runtime 已配置"

    # 测试 GPU 容器
    if timeout 10 docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
        pass "GPU 容器测试通过"
    else
        fail "GPU 容器测试失败"
    fi
elif command -v nvidia-ctk &> /dev/null; then
    warn "nvidia-ctk 已安装，但 Docker runtime 未配置"
    info "运行: sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker"
else
    fail "NVIDIA Container Toolkit 未安装"
    info "安装方法见部署指南"
fi
echo

# ============ 6. 网络端口 ============
echo "【6】网络端口检查"

check_port() {
    local port=$1
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
        warn "端口 ${port} 已被占用"
        ss -tlnp 2>/dev/null | grep ":${port} " | awk '{print "     进程: " $7}'
        return 1
    else
        pass "端口 ${port} 可用"
        return 0
    fi
}

check_port 8100
check_port 8081
check_port 7860
echo

# ============ 7. 可选功能 ============
echo "【7】可选功能"

# RealSense
if lsusb 2>/dev/null | grep -qi "Intel.*RealSense"; then
    info "检测到 RealSense 设备"
else
    info "未检测到 RealSense 设备（如不使用可忽略）"
fi

# zstd
if command -v zstd &> /dev/null; then
    pass "zstd 已安装（用于解压镜像）"
else
    warn "zstd 未安装（需要解压 .tar.zst 镜像）"
    info "安装: sudo apt install zstd"
fi
echo

# ============ 总结 ============
echo "========================================"
echo "检查完成"
echo "========================================"
echo -e "${GREEN}通过: ${PASS}${NC}  ${YELLOW}警告: ${WARN}${NC}  ${RED}失败: ${FAIL}${NC}"
echo

if [[ ${FAIL} -eq 0 ]]; then
    echo -e "${GREEN}✓ 系统满足部署条件${NC}"
    echo
    echo "后续步骤:"
    echo "  1. 传输镜像文件: mmk2-iros-demo-1.0.tar.zst"
    echo "  2. 校验完整性: sha256sum -c mmk2-iros-demo-1.0.sha256"
    echo "  3. 加载镜像: zstd -dc mmk2-iros-demo-1.0.tar.zst | docker load"
    echo "  4. 运行容器: ./mmk2-docker-run.sh"
    exit 0
else
    echo -e "${RED}✗ 系统不满足部署条件，请解决上述失败项${NC}"
    exit 1
fi
