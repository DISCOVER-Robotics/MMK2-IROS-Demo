#!/bin/bash
# MMK2 IROS Demo 快速部署总结
# 生成时间: 2026-07-27

cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║           MMK2 IROS Demo Docker 镜像 - 快速部署指南              ║
╚═══════════════════════════════════════════════════════════════════╝

📦 镜像信息
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  镜像名称:    mmk2-iros-demo:1.0
  原始大小:    32.5 GB
  压缩后:      14.4 GB (压缩率 44.11%)
  构建日期:    2026-07-27
  SHA256:      ae5fbada298049e649338f501353a5d7db79da8d0ad855f28307e0227f8cd2f5

🎯 已验证功能
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ Conda 环境 (mmk2_iros + s2r_bridge)
  ✓ MuJoCo 3.10 + EGL 无头渲染
  ✓ 3D Gaussian Splatting (3DGS)
  ✓ WebRTC 推流 (20fps, 1280x720)
  ✓ ROS2 Jazzy (RoboStack)
  ✓ GPU 加速 (CUDA 12.8, 显存 4.2GB)
  ✓ 真机连接 (gRPC 50055)

📋 交付文件清单
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. mmk2-iros-demo-1.0.tar.zst      (14.4 GB) - 镜像压缩包
  2. mmk2-iros-demo-1.0.sha256       (108 B)   - 校验和文件
  3. mmk2-docker-run.sh              (7.3 KB)  - 一键启动脚本
  4. mmk2-check-env.sh               (6.5 KB)  - 环境检查脚本
  5. mmk2-iros-demo-部署指南.md      (8.3 KB)  - 完整部署文档

🚀 目标机器快速部署（三步走）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  【步骤 1】环境检查
  ────────────────────────────────────────────────────────────────
    ./mmk2-check-env.sh

  检查项:
    - Ubuntu 22.04 / Linux 内核
    - CPU >= 8 核, 内存 >= 16GB, 磁盘 >= 40GB
    - NVIDIA GPU (RTX 30/40 系列推荐)
    - 驱动 >= 570.x (最低 535.x)
    - Docker >= 20.10
    - NVIDIA Container Toolkit

  【步骤 2】传输并加载镜像
  ────────────────────────────────────────────────────────────────
    # 传输文件（从源机器）
    rsync -avP --partial mmk2-iros-demo-1.0.tar.zst* user@target:/path/

    # 在目标机器上校验
    sha256sum -c mmk2-iros-demo-1.0.sha256

    # 加载镜像（需 10-15 分钟）
    zstd -dc mmk2-iros-demo-1.0.tar.zst | docker load

  【步骤 3】启动容器
  ────────────────────────────────────────────────────────────────
    # 默认配置（连接默认 IP 的真机）
    ./mmk2-docker-run.sh

    # 自定义真机 IP
    ROBOT_IP=192.168.1.100 ./mmk2-docker-run.sh

    # 使用 host 网络（简化网络配置）
    NETWORK_MODE=host ./mmk2-docker-run.sh

    启动后访问: http://<目标机IP>:8100

⚙️ 常用运行配置
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  场景 1: 连接真机（完整功能）
  ────────────────────────────────────────────────────────────────
    ROBOT_IP=<真机IP> ./mmk2-docker-run.sh

  场景 2: 使用 host 网络（避免端口映射问题）
  ────────────────────────────────────────────────────────────────
    NETWORK_MODE=host ROBOT_IP=<真机IP> ./mmk2-docker-run.sh

  场景 3: 启用 RealSense 相机
  ────────────────────────────────────────────────────────────────
    ENABLE_REALSENSE=true ROBOT_IP=<真机IP> ./mmk2-docker-run.sh

🔧 容器管理命令
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  查看日志:       docker logs -f mmk2_demo
  进入容器:       docker exec -it mmk2_demo bash
  查看状态:       docker stats mmk2_demo
  GPU 占用:       docker exec mmk2_demo nvidia-smi
  ROS2 话题:      docker exec mmk2_demo bash -lc 'source ~/miniconda3/etc/profile.d/conda.sh && conda activate s2r_bridge && ros2 topic list'

  停止容器:       docker stop mmk2_demo
  重启容器:       docker restart mmk2_demo
  删除容器:       docker rm -f mmk2_demo

🛡️ 关键注意事项
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⚠ 不要在容器内执行 pip install -e .（缺少 git 会失败）
  ⚠ 不要修改 conda 环境（editable 安装依赖绝对路径）
  ⚠ 不要删除 /home/discover/mmk2_iros_demo（环境依赖此路径）
  ⚠ 驱动版本 < 570 可能导致 CUDA 12.8 不兼容
  ⚠ GPU 非 Ampere/Ada 架构可能需要 PTX JIT（首帧慢）

🎓 技术细节
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  环境构成:
    - mmk2_iros  (11 GB):  gradio, ultralytics, pyrealsense2, av
    - s2r_bridge (9.5 GB): ROS2 Jazzy, mujoco, torch 2.11+cu128

  端口映射:
    - 8100: WebRTC 推流（仿真画面）
    - 8081: （预留）
    - 7860: Gradio Web UI

  资产裁剪（已从镜像移除）:
    - .git 目录（保留了 _version.py）
    - 未使用的 3DGS ply 文件（保留 4 个实际使用的）
    - MuJoCo-LiDAR 子模块（lidar_s2_sim=False）
    - 总裁剪量: 1.9G → 505M

📚 详细文档
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  完整部署指南:        mmk2-iros-demo-部署指南.md
  环境检查脚本:        mmk2-check-env.sh --help
  启动脚本帮助:        mmk2-docker-run.sh --help

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  构建日期: 2026-07-27
  构建主机: discover@mmk2-iros-demo (Ubuntu 22.04, RTX 3090)
  Docker 版本: 29.6.1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
