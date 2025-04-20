# 应用概述



#### ComfyUI 是一个灵活的用户界面（UI）框架，用于与深度学习模型进行交互，特别适用于图像生成和增强任务。在本文中，我们将探讨如何在 Kubernetes 集群中部署 ComfyUI，并集成强大的 Flux 文生图（Text-to-Image）模型和当前最火的 DeepSeek 深度学习模型，以增强图像生成的能力。

# 说明



- 首次启动需要下载自己下载模型,可以无卡启动，默认带卡启动

- 镜像在 l40s, h100上测试没问题。
- 预置模型路径：/alayanew/models
- ComfyUI 中自动下载的模型路径：/alayanew/models
- 基础环境：PyTorch 2.6.0, Python 3.11(ubuntu22.04), Cuda 12.8

# 功能介绍



- ComfyUI 20250418 最新版本，支持 FLUX、HunyuanVideo 、SD3等

- 预置 FLUX、HunyuanVideo 、高清放大等基本模型
- 预置 ControlnetNet 各种模型和预处理器
- 预置大量常用插件
- 调整了 ComfyUI 目录挪到了数据盘，方便扩容

# 有问题请联系

- 地址：https://www.yuque.com/u49853240/pgpa2z/qxgm5qnkqi5024kn)

  

# ChangeLog

- 20250418

  更新基础环境到 PyTorch 2.6.0, Python 3.11(ubuntu22.04), Cuda 12.8

  调整了 ComfyUI 本体的路径到数据盘，方便大家扩容和自行下载模型

  更新 ComfyUI 本体，支持 HunyuanVideo,并且预置了HunyuanVideo模型

  新增 HunyuanVideo 模型初始化脚本



# 获取ComfyUI地址
查看NOTES.txt 


### 选择模型

![image](https://caddy-x-caddy-x-vckg0tnisvp5.sproxy.hd-01.alayanew.com:22443/helm-images/comfyui/image1.png)

# 相关工作流以及部署教程



- https://www.yuque.com/u49853240/pgpa2z/qxgm5qnkqi5024kn


