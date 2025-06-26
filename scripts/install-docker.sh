#!/bin/bash

# Docker 安装脚本
# 适用于 Ubuntu/Debian 系统

set -e

echo "=== Docker 安装脚本 ==="
echo "开始安装Docker..."

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
   echo "请不要使用root用户运行此脚本" 
   exit 1
fi

# 更新系统包
echo "更新系统包..."
sudo apt update

# 安装必要的依赖包
echo "安装Docker依赖包..."
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 添加Docker官方GPG密钥
echo "添加Docker官方GPG密钥..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 添加Docker仓库
echo "添加Docker仓库..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新包索引
sudo apt update

# 安装Docker引擎
echo "安装Docker引擎..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 启动并启用Docker服务
echo "启动Docker服务..."
sudo systemctl start docker
sudo systemctl enable docker

# 将当前用户添加到docker组
echo "将用户 $USER 添加到docker组..."
sudo usermod -aG docker $USER

# 验证Docker安装
echo "验证Docker安装..."
if docker --version > /dev/null 2>&1; then
    echo "✅ Docker安装成功！"
    docker --version
else
    echo "❌ Docker安装失败！"
    exit 1
fi

# 检查Docker Compose
if docker compose version > /dev/null 2>&1; then
    echo "✅ Docker Compose安装成功！"
    docker compose version
else
    echo "❌ Docker Compose安装失败！"
    exit 1
fi

echo ""
echo "=== 安装完成 ==="
echo "请注意："
echo "1. 您需要重新登录或运行 'newgrp docker' 来刷新组权限"
echo "2. 之后可以不使用sudo直接运行docker命令"
echo ""
echo "测试命令："
echo "  newgrp docker"
echo "  docker run hello-world"
echo ""

# 创建docker配置目录
sudo mkdir -p /etc/docker

# 配置Docker daemon（可选，提高性能）
echo "配置Docker daemon..."
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

# 重启Docker服务以应用配置
sudo systemctl restart docker

echo "Docker配置完成！"
