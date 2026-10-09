# MMK2 IROS Prize Delivery Demo

[English](README.md) | [简体中文](README.zh-CN.md)

An MMK2 mobile manipulation demonstration for interactive prize delivery, medal-box handling, and automatic charging. This repository organizes the deployment and acceptance-test instructions for the original demonstration scene; it is not a general-purpose autonomous delivery system.

![MMK2 prize delivery workstation](assets/workstation.jpg)

## Availability

This repository contains documentation and the six original reference images only. Application source, Docker images, deployment scripts, SDK wheels, terminal installers, the third-party chassis app, and the showroom navigation map are **not included**.

The source document identifies `/home/discover/mmk2_iros_demo/mmk2-iros` as a deployment directory, not a public source repository. Obtain the matching deployment package from the demo maintainer before following installation commands. Do not substitute unrelated MMK2 releases.

## Hardware and safety

| Component | Original configuration |
| --- | --- |
| Robot | 1 MMK2 with two arms, grippers, and mobile base |
| Prize boxes | 12 boxes, 22 × 15 × 10.5 cm, wall thickness 0.2 cm |
| Host | Linux workstation with NVIDIA GPU |
| Network | Host must reach the robot and OrangePi controller |

Before connecting or restarting services, verify the robot IP, controller address, scene map, and target locations. Check whether the grippers hold objects. Clear the arms, spine, and mobile-base operating area and keep the emergency stop accessible. **Starting or stopping arm services can cause automatic robot motion.** Global relocalization also rotates the base.

## Software baseline

The instructions are based on acceptance document **V0.2.0 (2026-07-27)** and Docker image **`mmk2-iros-demo:1.0`**, built on 2026-07-27.

| Component | Documented version |
| --- | --- |
| OS / Docker base | Ubuntu 22.04 |
| Python | 3.12 |
| Conda environments | `mmk2_iros`, `s2r_bridge` |
| MediaPipe | 0.10.21; install with `--no-deps` when using the original host workflow |
| MMK2 SDK wheel | `mmk2_sdk` 0.0.4.dev5, supplied in the deployment project's `packages/` |
| Container components | Gradio 5.49.1, Ultralytics 8.4.95, AV 14.2.0, MuJoCo 3.10, Torch 2.11+cu128, DISCOVERSE 1.6.2, ROS 2 Jazzy via RoboStack |

The original minimum host requirements are 8 CPU cores, 16 GB RAM, 40 GB disk, an NVIDIA RTX 30/40-series GPU with 6 GB VRAM, driver 535.x or later, Docker 20.10 or later, and NVIDIA Container Toolkit. The recommended configuration is 12+ cores, 32 GB RAM, 60+ GB disk, RTX 3090/4090 with 12+ GB VRAM, and driver 570.x or later. Ensure sufficient additional space for image loading and extraction.

## Deployment

### Existing host installation

For an already provisioned demo machine, `mmk2-sim` and `mmk2-app` are configured to start automatically according to the source guide. Install the matching prize terminal provided by the maintainer. For Ubuntu, the original installer command is:

```bash
sudo dpkg -i mmk2-award-terminal_0.1.0_amd64.deb
```

Windows uses the version 0.1.0 terminal installer. Neither installer is distributed in this repository.

### Docker deployment

Obtain the complete `mmk2-deploy-package/` separately. It must contain the following files; these are not generated or supplied by this repository:

| File | Purpose |
| --- | --- |
| `mmk2-iros-demo-1.0.tar.zst` | Compressed image, approximately 14.4 GB (32.5 GB uncompressed image) |
| `mmk2-iros-demo-1.0.sha256` | Image checksum |
| `mmk2-check-env.sh` | Host and port checks |
| `mmk2-docker-run.sh` | Container launcher |
| `mmk2-iros-demo-部署指南.md` | Full deployment guide |
| `README-快速部署.txt` | Quick reference |

From that package directory, run:

```bash
./mmk2-check-env.sh
sha256sum -c mmk2-iros-demo-1.0.sha256
zstd -dc mmk2-iros-demo-1.0.tar.zst | docker load
docker images mmk2-iros-demo:1.0
```

After completing the hardware safety checks, launch with your actual robot address (replace the example `192.168.1.100`):

```bash
NETWORK_MODE=host ROBOT_IP=192.168.1.100 ./mmk2-docker-run.sh
```

The original script also supports `ENABLE_REALSENSE=true` for real cameras. Use the supplied deployment guide to configure networking and cameras; do not assume the screenshot addresses match your installation.

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

The screenshots retain the original Chinese terminal UI and example addresses; the default documentation is English.

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

The original general network table lists only video port 8081, while its Docker instructions and UI also use 8100. Check the actual service configuration and launcher port mappings rather than treating these tables as interchangeable.

On an existing systemd installation, after completing the safety checks:

```bash
sudo systemctl restart mmk2-sim
sleep 5
sudo systemctl restart mmk2-app
journalctl -u mmk2-sim -u mmk2-app -f
```

Reconnect the robot after restarting. The original log directory is `/home/discover/mmk2_iros_demo/mmk2-iros/logs`, with a documented seven-day cleanup interval. For Docker, use `docker logs -f mmk2_demo` and `docker exec mmk2_demo nvidia-smi` instead of assuming host systemd units exist.

| HTTP status | Expected meaning |
| --- | --- |
| `202` | Task accepted for background execution |
| `409` | A mutually exclusive task is already running |
| `422` | Invalid task or parameters, such as missing `prize_class`, row outside 1–3, or `prize_class` on `auto_charge` |
| `503` | Robot not connected |

For `gladLoadGL failed`, check `MUJOCO_GL=egl` and GPU drivers. For unavailable GPUs, check NVIDIA Container Toolkit. For failed robot connections, verify the robot address and gRPC port. Do not reinstall editable packages inside the original image: the source guide notes that Git is absent and recommends host-side development.

## Chassis map and localization

Use a site-approved map and obtain the compatible Slamtec app separately. The showroom map and third-party APK are intentionally not published here.

The original site procedure is to power-cycle the base using its power button, clear the operating area before releasing the brake/emergency stop, join the base Wi-Fi, and connect the app to `192.168.11.1:1445`. Upload the approved map and confirm it matches the site. Global relocalization rotates the base; keep the area clear. The source guide considers a localization quality above 90 successful for that scene.

![Original CANNOT_REACH_TARGET navigation log](assets/navigation-error.jpg)

For `CANNOT_REACH_TARGET`, the source guide identifies false map obstacles and motor faults as possible causes. Inspect the map and actual scene before changing obstacles; do not remove genuine safety obstacles to force a route.

## References and scope

| Resource | Location / availability |
| --- | --- |
| Product documentation | [DISCOVER Robotics Documentation Center](https://docs.discover-robotics.com/document/) |
| Original deployment reference | [Feishu document](https://w79rvfxw83.feishu.cn/docx/TmDudmBTqoUlzRx5bXrcNbOjnNb); unavailable during publication checks, access may be restricted |
| Source and deployment directory | `/home/discover/mmk2_iros_demo/mmk2-iros` on the original host; not a public download |

Content and images are organized from `MMK2 IROS Demo 提测文档.zip`. Versions and commands describe that supplied document, not newly verified hardware behavior. No robot services were started during preparation. No source-code license or redistribution rights for third-party binaries are asserted by this documentation repository.
