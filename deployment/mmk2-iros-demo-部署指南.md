# MMK2 IROS Demo Docker 镜像部署指南

## 一、镜像信息

- **镜像名称**: `mmk2-iros-demo:1.0`
- **基础镜像**: Ubuntu 22.04
- **大小**: 约 32.5 GB（压缩后约 9-12 GB）
- **构建日期**: 2026-07-27
- **GPU 要求**: NVIDIA RTX 3090 或同代 GPU，驱动 >= 570.x

## 二、目标机器前置条件

### 2.1 硬件要求
- **GPU**: NVIDIA Ampere 架构或更新（RTX 30/40 系列、A 系列）
- **显存**: >= 6GB（推荐 12GB+）
- **内存**: >= 16GB（推荐 32GB+）
- **磁盘**: >= 40GB 可用空间

### 2.2 软件要求

#### 必需项
```bash
# 1. NVIDIA 驱动（>= 570.x 最佳，最低 535.x）
nvidia-smi

# 2. Docker（>= 20.10）
docker --version

# 3. NVIDIA Container Toolkit
docker info | grep -i runtime
# 应显示 nvidia runtime
```

#### 安装 NVIDIA Container Toolkit（如未安装）
```bash
# Ubuntu/Debian
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

#### 验证 GPU 容器支持
```bash
docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu22.04 nvidia-smi
```

## 三、镜像传输与加载

### 3.1 传输镜像文件
从源机器传输两个文件到目标机器：
- `mmk2-iros-demo-1.0.tar.zst`（约 9-12 GB）
- `mmk2-iros-demo-1.0.sha256`（校验和）

```bash
# 方法 1: rsync（推荐，支持断点续传）
rsync -avP --partial mmk2-iros-demo-1.0.tar.zst user@target:/path/to/dest/

# 方法 2: scp
scp mmk2-iros-demo-1.0.tar.zst* user@target:/path/to/dest/
```

### 3.2 校验完整性
```bash
cd /path/to/dest
sha256sum -c mmk2-iros-demo-1.0.sha256
# 应显示: mmk2-iros-demo-1.0.tar.zst: OK
```

### 3.3 加载镜像
```bash
# 解压并加载（需 10-20 分钟）
zstd -dc mmk2-iros-demo-1.0.tar.zst | docker load

# 验证
docker images mmk2-iros-demo:1.0
```

## 四、运行配置

### 4.1 场景 1: 纯仿真（不连真机）

⚠️ **当前限制**: `shadow_bridge.py` 必须连接真机才能启动，即使 `--base-mode off` 也需要 gRPC 连接成功。纯仿真需要单独启动 `s2r_server.py`（见 4.3）。

### 4.2 场景 2: 连接真机（完整功能）

```bash
# 确保真机可达
nc -zv <ROBOT_IP> 50055

# 启动容器
docker run -d --gpus all \
  --name mmk2_demo \
  -p 8100:8100 -p 8081:8081 -p 7860:7860 \
  -v /path/to/logs:/home/discover/mmk2_iros_demo/mmk2-iros/logs \
  -e MUJOCO_GL=egl \
  -e ROS_DOMAIN_ID=0 \
  -e ROS_LOCALHOST_ONLY=0 \
  mmk2-iros-demo:1.0 \
  bash -lc './scripts/sim/run_demo.sh --round-id 1 --base-mode off'

# 修改真机 IP（如果不是 172.100.11.251）
docker run -d --gpus all \
  --name mmk2_demo \
  -p 8100:8100 -p 8081:8081 -p 7860:7860 \
  -e MUJOCO_GL=egl \
  -e ROS_DOMAIN_ID=0 \
  -e ROS_LOCALHOST_ONLY=0 \
  mmk2-iros-demo:1.0 \
  bash -lc 'sed -i "s/172.100.11.251/<YOUR_ROBOT_IP>/" configs/task.yaml && \
            ./scripts/sim/run_demo.sh --round-id 1 --base-mode off'
```

### 4.3 场景 3: 仅启动仿真服务器（不启动桥接）

```bash
docker run -d --gpus all \
  --name mmk2_s2r \
  -p 8100:8100 \
  -e MUJOCO_GL=egl \
  -e ROS_DOMAIN_ID=0 \
  mmk2-iros-demo:1.0 \
  bash -lc 'cd /home/discover/mmk2_iros_demo/mmk2_SIM/mmk2-iros-sim/s2r2025 && \
            source ~/miniconda3/etc/profile.d/conda.sh && \
            conda activate s2r_bridge && \
            python3 s2r_server.py --round_id 1'
```

### 4.4 RealSense 相机支持（如需使用真实相机）

```bash
docker run -d --gpus all \
  --name mmk2_demo \
  --device-cgroup-rule='c 189:* rmw' \
  -v /dev/bus/usb:/dev/bus/usb \
  -p 8100:8100 -p 8081:8081 -p 7860:7860 \
  -e MUJOCO_GL=egl \
  mmk2-iros-demo:1.0 \
  bash -lc './scripts/sim/run_demo.sh --round-id 1 --base-mode off'
```

## 五、访问与验证

### 5.1 WebRTC 实时画面
浏览器打开: **http://<目标机IP>:8100**

应看到仿真场景实时渲染画面（20 FPS, 1280x720）

### 5.2 检查服务状态
```bash
# 查看日志
docker logs -f mmk2_demo

# 查看进程
docker exec mmk2_demo ps aux | grep python

# 查看端口
docker exec mmk2_demo ss -tlnp | grep -E '8100|8081|7860'

# 查看 GPU 占用
docker exec mmk2_demo nvidia-smi
```

### 5.3 ROS2 话题检查
```bash
docker exec mmk2_demo bash -lc '
source ~/miniconda3/etc/profile.d/conda.sh && \
conda activate s2r_bridge && \
ros2 topic list
'
```

### 5.4 交互式进入容器
```bash
docker exec -it mmk2_demo bash

# 容器内手动激活环境
source ~/miniconda3/etc/profile.d/conda.sh
conda activate s2r_bridge  # 或 mmk2_iros
```

## 六、故障排查

### 6.1 GPU 相关

**问题**: `gladLoadGL failed`
```bash
# 检查 MUJOCO_GL
docker exec mmk2_demo bash -c 'echo $MUJOCO_GL'  # 应为 egl

# 检查驱动
nvidia-smi
docker exec mmk2_demo nvidia-smi
```

**问题**: CUDA 版本不匹配
- 镜像内 PyTorch 需要 CUDA 12.8，驱动 >= 570.x
- 低版本驱动可能导致 cu128 wheel 无法加载

### 6.2 端口冲突

**问题**: `address already in use`
```bash
# 检查宿主端口占用
ss -tlnp | grep -E '8100|8081|7860'

# 改用其他端口映射
docker run ... -p 18100:8100 -p 18081:8081 ...
```

### 6.3 网络与真机连接

**问题**: 无法连接真机 50055
```bash
# 检查网络可达性
ping <ROBOT_IP>
nc -zv <ROBOT_IP> 50055

# 使用 host 网络（简化网络配置）
docker run --network host ...
```

**问题**: ROS2 DDS 发现失败
- 使用 `--network host` 模式
- 或确保 `ROS_DOMAIN_ID` 一致
- 防火墙放行 UDP 7400-7500

### 6.4 性能问题

**问题**: WebRTC 帧率低或卡顿
```bash
# 检查 GPU 利用率
docker exec mmk2_demo nvidia-smi
# 应有 30-50% 利用率

# 检查 CPU 占用
docker stats mmk2_demo
# server 进程应有 120-150% CPU（多线程）
```

## 七、容器管理

### 7.1 常用命令
```bash
# 启动/停止
docker start mmk2_demo
docker stop mmk2_demo

# 重启
docker restart mmk2_demo

# 删除容器
docker rm -f mmk2_demo

# 删除镜像
docker rmi mmk2-iros-demo:1.0
```

### 7.2 持久化数据
容器内 `/home/discover/mmk2_iros_demo/mmk2-iros/logs` 建议挂载到宿主：
```bash
-v /host/path/logs:/home/discover/mmk2_iros_demo/mmk2-iros/logs
```

### 7.3 资源限制
```bash
# 限制内存和 CPU
docker run --gpus all --memory=16g --cpus=8 ...
```

## 八、重要提醒

⚠️ **不要在容器内执行以下操作**:
1. `pip install -e .` — 会因缺少 git 而失败（setuptools_scm）
2. 修改 conda 环境 — 环境已完整打包，改动会破坏 editable 安装
3. 删除 `/home/discover/mmk2_iros_demo` — editable 包依赖此路径

⚠️ **路径限制**:
- 环境路径: `/home/discover/miniconda3/envs/*`
- 项目路径: `/home/discover/mmk2_iros_demo/*`
- 这两个路径**必须与宿主机一致**，否则 editable 安装的 `.pth` 文件会失效

⚠️ **裁剪的资产**（已从镜像移除）:
- `.git` 目录（如需版本信息，参考保留的 `_version.py`）
- `models/3dgs/scene/s2r2025/point_cloud.ply`（背景用 `mmk_demo_aligned.ply`）
- 未使用的 3DGS 道具 ply（保留了 box/sheet_01/disk_01/carton_01）
- `MuJoCo-LiDAR` 子模块（`lidar_s2_sim=False`）

## 九、技术细节

### 9.1 环境构成
| 环境 | Python | 主要组件 | 大小 |
|---|---|---|---|
| `mmk2_iros` | 3.12 | gradio 5.49.1, ultralytics 8.4.95, pyrealsense2, av 14.2.0 | 11 GB |
| `s2r_bridge` | 3.12 | ROS2 Jazzy (RoboStack), mujoco 3.10, torch 2.11+cu128, discoverse 1.6.2 | 9.5 GB |

### 9.2 端口说明
- **8100**: WebRTC 推流（仿真画面）
- **8081**: （预留）
- **7860**: Gradio Web UI

### 9.3 GPU 架构兼容性
镜像内 `diff_gaussian_rasterization/_C.so` 编译目标:
- 假设为 sm_86（RTX 3090 Ampere）
- 新架构（Ada/Hopper）通过 PTX JIT 兼容，但首帧会慢
- 旧架构（Pascal/Volta）可能不支持

目标机 GPU 如非 RTX 30/40 系列，建议提前验证。

---

**文档版本**: 1.0  
**更新日期**: 2026-07-27  
**联系方式**: [预留]
