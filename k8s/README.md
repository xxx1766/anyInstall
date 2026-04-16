# Kubernetes 一键安装 (Debian/Ubuntu)

安装内容：
- containerd
- kubeadm / kubelet / kubectl（交互式选择版本，支持 v1.28 ~ v1.32）
- 可选：初始化 Master 节点或加入 Worker 节点

镜像源使用中科大镜像（GPG/APT）+ 阿里云镜像（kubeadm init）。

## 使用方法

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/xxx1766/anyInstall/main/k8s/install.sh)
```

> 需要 root 或 sudo 权限。脚本会交互式引导完成版本选择和节点配置。
