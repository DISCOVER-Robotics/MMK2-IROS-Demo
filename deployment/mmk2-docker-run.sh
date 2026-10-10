#!/bin/bash
# MMK2 IROS Demo Docker 启动脚本
# 版本: 1.0
# 日期: 2026-07-27

set -euo pipefail

# ============ 配置区 ============
IMAGE="mmk2-iros-demo:1.0"
CONTAINER_NAME="mmk2_demo"
ROBOT_IP="${ROBOT_IP:-172.100.11.251}"  # 从环境变量读取，默认 172.100.11.251
ROBOT_PORT="${ROBOT_PORT:-50055}"
LOGS_DIR="${LOGS_DIR:-./logs}"          # 日志挂载目录
ROUND_ID="${ROUND_ID:-1}"               # 回合 ID
BASE_MODE="${BASE_MODE:-off}"           # 底盘模式: off/real/choreograph

# 网络模式: host 或 bridge（默认 bridge，需端口映射）
NETWORK_MODE="${NETWORK_MODE:-bridge}"

# 是否启用 RealSense USB 设备
ENABLE_REALSENSE="${ENABLE_REALSENSE:-false}"

# ============ 颜色输出 ============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ============ 前置检查 ============
check_prerequisites() {
    info "检查前置条件..."

    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        error "Docker 未安装"
    fi

    # 检查 NVIDIA Docker 支持
    if ! docker info 2>/dev/null | grep -q nvidia; then
        error "NVIDIA Container Runtime 未配置，请运行: sudo nvidia-ctk runtime configure --runtime=docker"
    fi

    # 检查镜像
    if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE}$"; then
        error "镜像 ${IMAGE} 不存在，请先加载: zstd -dc mmk2-iros-demo-1.0.tar.zst | docker load"
    fi

    # 检查 GPU
    if ! nvidia-smi &> /dev/null; then
        error "nvidia-smi 不可用，请检查驱动"
    fi

    # 测试 GPU 容器
    if ! docker run --rm --gpus all ${IMAGE} nvidia-smi &> /dev/null; then
        error "GPU 容器测试失败"
    fi

    info "前置检查通过 ✓"
}

# ============ 网络检查 ============
check_robot_connection() {
    if [[ "${BASE_MODE}" != "off" ]] || [[ "${NETWORK_MODE}" == "host" ]]; then
        info "检查真机连接: ${ROBOT_IP}:${ROBOT_PORT}"
        if timeout 3 nc -zv "${ROBOT_IP}" "${ROBOT_PORT}" &> /dev/null; then
            info "真机可达 ✓"
        else
            warn "真机 ${ROBOT_IP}:${ROBOT_PORT} 不可达（如为纯仿真可忽略）"
        fi
    fi
}

# ============ 清理旧容器 ============
cleanup_old_container() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        warn "发现已存在的容器 ${CONTAINER_NAME}，正在删除..."
        docker rm -f "${CONTAINER_NAME}" > /dev/null
    fi
}

# ============ 构建启动参数 ============
build_docker_args() {
    local args=(
        "-d"
        "--gpus" "all"
        "--name" "${CONTAINER_NAME}"
        "-e" "MUJOCO_GL=egl"
        "-e" "PYOPENGL_PLATFORM=egl"
        "-e" "ROS_DOMAIN_ID=0"
    )

    # 网络模式
    if [[ "${NETWORK_MODE}" == "host" ]]; then
        args+=("--network" "host")
        args+=("-e" "ROS_LOCALHOST_ONLY=0")
    else
        args+=("-p" "8100:8100" "-p" "8081:8081" "-p" "7860:7860")
        args+=("-e" "ROS_LOCALHOST_ONLY=0")
    fi

    # 日志挂载
    mkdir -p "${LOGS_DIR}"
    args+=("-v" "$(realpath ${LOGS_DIR}):/home/discover/mmk2_iros_demo/mmk2-iros/logs")

    # RealSense USB 设备
    if [[ "${ENABLE_REALSENSE}" == "true" ]]; then
        args+=("--device-cgroup-rule=c 189:* rmw")
        args+=("-v" "/dev/bus/usb:/dev/bus/usb")
    fi

    args+=("${IMAGE}")

    # 启动命令
    local cmd="bash -lc '"
    if [[ "${ROBOT_IP}" != "172.100.11.251" ]]; then
        cmd+="sed -i \"s/172.100.11.251/${ROBOT_IP}/\" configs/task.yaml && "
    fi
    cmd+="./scripts/sim/run_demo.sh --round-id ${ROUND_ID} --base-mode ${BASE_MODE}'"
    args+=("${cmd}")

    echo "${args[@]}"
}

# ============ 启动容器 ============
start_container() {
    info "启动容器..."
    info "配置:"
    info "  - 镜像: ${IMAGE}"
    info "  - 容器名: ${CONTAINER_NAME}"
    info "  - 真机: ${ROBOT_IP}:${ROBOT_PORT}"
    info "  - 底盘模式: ${BASE_MODE}"
    info "  - 网络模式: ${NETWORK_MODE}"
    info "  - 日志目录: ${LOGS_DIR}"
    info "  - RealSense: ${ENABLE_REALSENSE}"

    local docker_args
    docker_args=$(build_docker_args)

    # shellcheck disable=SC2086
    if docker run ${docker_args}; then
        info "容器已启动 ✓"
    else
        error "容器启动失败"
    fi
}

# ============ 等待服务就绪 ============
wait_for_services() {
    info "等待服务初始化（最多 30 秒）..."

    local max_wait=30
    local elapsed=0

    while [[ ${elapsed} -lt ${max_wait} ]]; do
        if docker logs "${CONTAINER_NAME}" 2>&1 | grep -q "WebRTC.*服务已启动"; then
            info "WebRTC 服务已就绪 ✓"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    warn "服务初始化超时，请手动检查: docker logs ${CONTAINER_NAME}"
}

# ============ 显示访问信息 ============
show_access_info() {
    info "========================================="
    info "部署完成！"
    info "========================================="

    if [[ "${NETWORK_MODE}" == "host" ]]; then
        info "WebRTC 推流: http://localhost:8100"
        info "Gradio UI: http://localhost:7860"
    else
        local host_ip
        host_ip=$(hostname -I | awk '{print $1}')
        info "WebRTC 推流: http://${host_ip}:8100"
        info "Gradio UI: http://${host_ip}:7860"
    fi

    info ""
    info "常用命令:"
    info "  查看日志:     docker logs -f ${CONTAINER_NAME}"
    info "  进入容器:     docker exec -it ${CONTAINER_NAME} bash"
    info "  停止容器:     docker stop ${CONTAINER_NAME}"
    info "  重启容器:     docker restart ${CONTAINER_NAME}"
    info "  删除容器:     docker rm -f ${CONTAINER_NAME}"
    info "========================================="
}

# ============ 主流程 ============
main() {
    echo "MMK2 IROS Demo Docker 启动脚本"
    echo "======================================"
    echo

    check_prerequisites
    check_robot_connection
    cleanup_old_container
    start_container
    wait_for_services
    show_access_info
}

# ============ 使用帮助 ============
usage() {
    cat << EOF
用法: $0 [OPTIONS]

环境变量:
  ROBOT_IP              真机 IP（默认: 172.100.11.251）
  ROBOT_PORT            真机端口（默认: 50055）
  LOGS_DIR              日志目录（默认: ./logs）
  ROUND_ID              回合 ID（默认: 1）
  BASE_MODE             底盘模式（默认: off）
                        - off: 不发底盘指令
                        - real: 读真机底盘
                        - choreograph: 编排底盘轨迹
  NETWORK_MODE          网络模式（默认: bridge）
                        - bridge: 端口映射
                        - host: 主机网络
  ENABLE_REALSENSE      启用 RealSense USB（默认: false）

示例:
  # 默认配置启动
  $0

  # 指定真机 IP
  ROBOT_IP=192.168.1.100 $0

  # 使用 host 网络
  NETWORK_MODE=host $0

  # 启用 RealSense 相机
  ENABLE_REALSENSE=true $0

  # 组合配置
  ROBOT_IP=192.168.1.100 BASE_MODE=real NETWORK_MODE=host $0

EOF
}

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

main "$@"
