#!/bin/bash
set -e

# 下载官方安装脚本
curl -fsSL https://get.docker.com -o get-docker.sh

# 执行脚本（大概需要等 1-3 分钟）
sudo sh get-docker.sh
