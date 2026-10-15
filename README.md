# MMK2 IROS Prize Delivery Demo

[English](README.md) | [简体中文](README.zh-CN.md)

An MMK2 mobile manipulation demonstration for interactive prize delivery, medal-box handling, and automatic charging. The demo uses a configured workstation and scene; it is not a general-purpose autonomous delivery system.

![MMK2 prize delivery workstation](assets/workstation.jpg)

## Availability

This repository contains deployment instructions, six images, and deployment helper files. The 14.4 GB Docker image, application source, SDK wheels, terminal installers, the third-party chassis app, and the showroom navigation map are **not stored in Git**.

`/home/discover/mmk2_iros_demo/mmk2-iros` is a local directory on the deployment host, not a public source repository. Obtain the matching deployment package from the demo maintainer before following installation commands. Do not substitute unrelated MMK2 releases.

## Hardware and safety

| Component | Configuration |
| --- | --- |
| Robot | 1 MMK2 with two arms, grippers, and mobile base |
| Prize boxes | 12 boxes, 22 × 15 × 10.5 cm, wall thickness 0.2 cm |
| Host | Linux workstation with NVIDIA GPU |
| Network | Host must reach the robot and OrangePi controller |

Before connecting or restarting services, verify the robot IP, controller address, scene map, and target locations. Check whether the grippers hold objects. Clear the arms, spine, and mobile-base operating area and keep the emergency stop accessible. **Starting or stopping arm services can cause automatic robot motion.** Global relocalization also rotates the base.

## Software baseline

Guide version: **V0.2.0 (2026-07-27)**. Docker image: **`mmk2-iros-demo:1.0`**, built on 2026-07-27.

| Component | Version |
| --- | --- |
| OS / Docker base | Ubuntu 22.04 |
| Python | 3.12 |
| Conda environments | `mmk2_iros`, `s2r_bridge` |
| MediaPipe | 0.10.21; install with `--no-deps` when using the host workflow |
| MMK2 SDK wheel | `mmk2_sdk` 0.0.4.dev5, supplied in the deployment project's `packages/` |
| Container components | Gradio 5.49.1, Ultralytics 8.4.95, AV 14.2.0, MuJoCo 3.10, Torch 2.11+cu128, DISCOVERSE 1.6.2, ROS 2 Jazzy via RoboStack |

The minimum host requirements are 8 CPU cores, 16 GB RAM, 40 GB disk, an NVIDIA RTX 30/40-series GPU with 6 GB VRAM, driver 535.x or later, Docker 20.10 or later, and NVIDIA Container Toolkit. The recommended configuration is 12+ cores, 32 GB RAM, 60+ GB disk, RTX 3090/4090 with 12+ GB VRAM, and driver 570.x or later. Ensure sufficient additional space for image loading and extraction.

## Deployment

### Existing host installation

On a provisioned demo machine, `mmk2-sim` and `mmk2-app` are configured to start automatically. Install the matching prize terminal provided by the maintainer. For Ubuntu:

```bash
sudo dpkg -i mmk2-award-terminal_0.1.0_amd64.deb
```

Windows uses the version 0.1.0 terminal installer. Neither installer is distributed in this repository.

### Docker deployment

The deployment helper files are available in [`deployment/`](deployment/). Download the Docker image separately, place it beside the checksum file, and run the checks below. The image itself is not stored in Git because it is approximately 14.4 GB.

### Download the Docker image

Use the complete archive from **`image-v1.0-complete`**. Do not mix its parts or checksum files with those from the older `image-v1.0` Release.

Download all **eight parts (`part-00` through `part-07`)**, `mmk2-iros-demo-1.0-parts.sha256`, and `mmk2-iros-demo-1.0.sha256` from the [image-v1.0-complete Release](https://github.com/DISCOVER-Robotics/MMK2-IROS-Demo/releases/tag/image-v1.0-complete). Each part is below GitHub's 2 GiB attachment limit. Parts are not separate Docker images and cannot be loaded individually.

Place the downloads in one directory and run the following on Linux. Keep at least 29 GB free for the parts and merged archive, plus additional space for Docker image extraction. Do not overwrite an existing archive without checking it first.

```bash
sha256sum -c mmk2-iros-demo-1.0-parts.sha256 || exit 1
# Stop if any part fails verification. Do not overwrite an existing merged archive.
test ! -e mmk2-iros-demo-1.0.tar.zst || exit 1
cat mmk2-iros-demo-1.0.tar.zst.part-{00..07} > mmk2-iros-demo-1.0.tar.zst || exit 1
sha256sum -c mmk2-iros-demo-1.0.sha256 || exit 1
zstd -t mmk2-iros-demo-1.0.tar.zst || exit 1
```

Continue only if every checksum reports `OK` and `zstd -t mmk2-iros-demo-1.0.tar.zst` confirms archive integrity. Obtain the scripts below from `deployment/` and place them in the same directory before proceeding. The checksum confirms that the download matches the supplied file, not archive completeness, hardware compatibility, or image authenticity.

| File | Purpose |
| --- | --- |
| [`mmk2-check-env.sh`](deployment/mmk2-check-env.sh) | Host and port checks |
| [`mmk2-docker-run.sh`](deployment/mmk2-docker-run.sh) | Container launcher |
| [`mmk2-iros-demo-部署指南.md`](deployment/mmk2-iros-demo-部署指南.md) | Full deployment guide |
| [`README-快速部署.txt`](deployment/README-快速部署.txt) | Quick reference |
| [`mmk2-iros-demo-1.0.sha256`](deployment/mmk2-iros-demo-1.0.sha256) | SHA256 for the complete merged archive |
| [`mmk2-iros-demo-1.0-parts.sha256`](deployment/mmk2-iros-demo-1.0-parts.sha256) | SHA256 for all eight parts in `image-v1.0-complete` |

From the directory containing the image, run:

```bash
chmod +x mmk2-check-env.sh mmk2-docker-run.sh
./mmk2-check-env.sh
sha256sum -c mmk2-iros-demo-1.0.sha256 || exit 1
zstd -t mmk2-iros-demo-1.0.tar.zst || exit 1
set -o pipefail
zstd -dc mmk2-iros-demo-1.0.tar.zst | docker load
docker images mmk2-iros-demo:1.0
```

The complete archive has SHA256 `ae5fbada298049e649338f501353a5d7db79da8d0ad855f28307e0227f8cd2f5`, matching the deployment package checksum. Its Zstandard integrity test and full tar archive read passed. These checks validate the archive, not GPU compatibility or physical robot operation.

After completing the hardware safety checks, launch with your actual robot address (replace the example `192.168.1.100`):

```bash
NETWORK_MODE=host ROBOT_IP=192.168.1.100 ./mmk2-docker-run.sh
```

The launcher also supports `ENABLE_REALSENSE=true` for real cameras. Use the deployment guide to configure networking and cameras; do not assume the screenshot addresses match your installation.

## Run the demonstration

1. Open the prize terminal application.
2. Open robot configuration using the middle button at the upper right. Set the robot IP, API address, and video endpoints. Save the configuration and connect the robot.
3. Configure and save the prize probabilities, then return to the main screen.
4. Start the lottery. Wait for the robot to retrieve and present the prize, then end prize collection before starting the next round.
5. When both boxes of a prize category are exhausted, replenish them and restore the scene. **Disconnect and reconnect the robot** to refresh both task and simulation state.

![Terminal application entry](assets/application-entry.png)

![Lottery main screen](assets/lottery-screen.jpg)

<img src="assets/robot-configuration.jpg" alt="Robot connection, service endpoints, and prize probabilities" width="446">

![Prize collection screen](assets/prize-collection.jpg)

The screenshots show the Chinese terminal UI. Replace example addresses with those of your installation.

## Services and troubleshooting

| Service | Documented endpoint |
| --- | --- |
| Arm gRPC | Robot port `50055` |
| Chassis HTTP | Controller port `8800` |
| Lighting HTTP | Controller port `8810` |
| Gradio | `http://<HOST>:7860` |
| FastAPI / Swagger / OpenAPI | `http://<HOST>:8000`, `/docs`, `/openapi.json` |
| Simulation WebRTC | `http://<HOST>:8100` (configuration screenshot uses `/offer`) |
| Head-camera WebRTC | `http://<HOST>:8081` (configuration screenshot uses `/offer`) |

Video services use ports 8081 and 8100. Check the actual service configuration and launcher port mappings for each endpoint.

On an existing systemd installation, after completing the safety checks:

```bash
sudo systemctl restart mmk2-sim
sleep 5
sudo systemctl restart mmk2-app
journalctl -u mmk2-sim -u mmk2-app -f
```

Reconnect the robot after restarting. The host log directory is `/home/discover/mmk2_iros_demo/mmk2-iros/logs`, with a seven-day cleanup interval. For Docker, use `docker logs -f mmk2_demo` and `docker exec mmk2_demo nvidia-smi` instead of assuming host systemd units exist.

| HTTP status | Expected meaning |
| --- | --- |
| `202` | Task accepted for background execution |
| `409` | A mutually exclusive task is already running |
| `422` | Invalid task or parameters, such as missing `prize_class`, row outside 1–3, or `prize_class` on `auto_charge` |
| `503` | Robot not connected |

For `gladLoadGL failed`, check `MUJOCO_GL=egl` and GPU drivers. For unavailable GPUs, check NVIDIA Container Toolkit. For failed robot connections, verify the robot address and gRPC port. Git is not installed in the image; do not reinstall editable packages inside the container. Use the host for development.

## Chassis map and localization

Use a site-approved map and obtain the compatible Slamtec app separately. The showroom map and third-party APK are intentionally not published here.

Power-cycle the base using its power button, clear the operating area before releasing the brake/emergency stop, join the base Wi-Fi, and connect the app to `192.168.11.1:1445`. Upload the approved map and confirm it matches the site. Global relocalization rotates the base; keep the area clear. For this demonstration scene, localization quality must exceed 90.

![CANNOT_REACH_TARGET navigation log](assets/navigation-error.jpg)

For `CANNOT_REACH_TARGET`, possible causes include false map obstacles and motor faults. Inspect the map and actual scene before changing obstacles; do not remove genuine safety obstacles to force a route.

## Resources

| Resource | Location / availability |
| --- | --- |
| Product documentation | [DISCOVER Robotics Documentation Center](https://docs.discover-robotics.com/document/) |
| Deployment guide | [Feishu document](https://w79rvfxw83.feishu.cn/docx/TmDudmBTqoUlzRx5bXrcNbOjnNb); access permission may be required |
| Source and deployment directory | `/home/discover/mmk2_iros_demo/mmk2-iros` on the deployment host; not a public download |

This repository does not grant a license to the application source or redistribution rights for third-party binaries.
