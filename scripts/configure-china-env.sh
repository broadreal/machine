#!/bin/bash

# 中国大陆网络环境优化配置脚本

set -e

echo "=== 中国大陆网络环境优化配置 ==="

# 配置变量
ENV_DIR="/home/user/machine/venv"
HF_HOME="/home/user/machine/models/.cache/huggingface"
MODELSCOPE_CACHE="/home/user/machine/models/.cache/modelscope"

# 创建缓存目录
mkdir -p "$HF_HOME"
mkdir -p "$MODELSCOPE_CACHE"

# 1. 配置pip镜像源
echo "配置pip镜像源..."
if [ -d "$ENV_DIR" ]; then
    source "$ENV_DIR/bin/activate"
fi

# 配置pip
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
pip config set install.trusted-host mirrors.aliyun.com
pip config set global.timeout 300

echo "✅ pip镜像源配置完成"

# 2. 配置Hugging Face镜像
echo "配置Hugging Face环境变量..."
ENV_FILE="/home/user/machine/.env"
cat > "$ENV_FILE" << EOF
# Hugging Face 镜像配置
export HF_ENDPOINT=https://hf-mirror.com
export HF_HOME=$HF_HOME
export HUGGINGFACE_HUB_CACHE=$HF_HOME

# ModelScope 配置
export MODELSCOPE_CACHE=$MODELSCOPE_CACHE

# CUDA 配置
export CUDA_VISIBLE_DEVICES=0,1,2,3
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128

# vLLM 配置
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ATTENTION_BACKEND=FLASH_ATTN

# 网络优化
export HTTP_PROXY=""
export HTTPS_PROXY=""
export NO_PROXY="localhost,127.0.0.1"

# Python 环境
export PYTHONPATH=/home/user/machine:\$PYTHONPATH
export PYTHONIOENCODING=utf-8
EOF

# 3. 配置系统环境变量
echo "配置系统环境变量..."
BASHRC_ADDITIONS="

# AI推理环境配置
source /home/user/machine/.env

# 激活虚拟环境别名
alias activate-ai='source /home/user/machine/venv/bin/activate && source /home/user/machine/.env'
alias check-gpu='nvidia-smi'
alias check-vllm='curl -s http://localhost:8000/health || echo \"vLLM服务未运行\"'
"

# 检查是否已经添加过
if ! grep -q "AI推理环境配置" ~/.bashrc; then
    echo "$BASHRC_ADDITIONS" >> ~/.bashrc
    echo "✅ 环境变量已添加到 ~/.bashrc"
else
    echo "✅ 环境变量已存在于 ~/.bashrc"
fi

# 4. 配置Git (如果需要clone模型)
echo "配置Git镜像..."
if command -v git > /dev/null 2>&1; then
    git config --global url."https://gitee.com/mirrors/".insteadOf "https://github.com/"
    git config --global url."https://hub.fastgit.xyz/".insteadOf "https://github.com/"
    echo "✅ Git镜像配置完成"
fi

# 5. 下载加速工具
echo "安装下载加速工具..."
if [ -d "$ENV_DIR" ]; then
    source "$ENV_DIR/bin/activate"
    pip install huggingface-hub hf-transfer -i https://mirrors.aliyun.com/pypi/simple/
    echo "✅ 下载加速工具安装完成"
fi

# 6. 创建模型下载脚本
DOWNLOAD_HELPER="/home/user/machine/scripts/download-helper.py"
cat > "$DOWNLOAD_HELPER" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
模型下载助手 - 支持断点续传和多线程下载
"""

import os
import sys
import requests
import threading
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import time

class ModelDownloader:
    def __init__(self, use_mirror=True):
        self.use_mirror = use_mirror
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36'
        })
        
    def download_file(self, url, local_path, chunk_size=8192):
        """下载文件with断点续传"""
        local_path = Path(local_path)
        local_path.parent.mkdir(parents=True, exist_ok=True)
        
        # 检查已下载的大小
        resume_pos = 0
        if local_path.exists():
            resume_pos = local_path.stat().st_size
            
        headers = {}
        if resume_pos > 0:
            headers['Range'] = f'bytes={resume_pos}-'
            
        try:
            response = self.session.get(url, headers=headers, stream=True, timeout=30)
            response.raise_for_status()
            
            total_size = int(response.headers.get('content-length', 0)) + resume_pos
            
            mode = 'ab' if resume_pos > 0 else 'wb'
            with open(local_path, mode) as f:
                downloaded = resume_pos
                for chunk in response.iter_content(chunk_size=chunk_size):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        # 进度显示
                        if total_size > 0:
                            percent = (downloaded / total_size) * 100
                            print(f'\r下载进度: {percent:.1f}% ({downloaded}/{total_size}字节)', end='')
                            
            print(f'\n✅ 下载完成: {local_path}')
            return True
            
        except Exception as e:
            print(f'\n❌ 下载失败: {e}')
            return False
            
    def download_model_from_modelscope(self, model_id, local_dir):
        """从ModelScope下载模型"""
        print(f"从ModelScope下载模型: {model_id}")
        
        try:
            from modelscope.hub.snapshot_download import snapshot_download
            snapshot_download(
                model_id=model_id,
                cache_dir=local_dir,
                local_files_only=False
            )
            print(f"✅ ModelScope模型下载完成: {local_dir}")
            return True
            
        except Exception as e:
            print(f"❌ ModelScope下载失败: {e}")
            return False

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("用法: python download-helper.py <model_id> <local_dir>")
        sys.exit(1)
        
    model_id = sys.argv[1]
    local_dir = sys.argv[2]
    
    downloader = ModelDownloader()
    success = downloader.download_model_from_modelscope(model_id, local_dir)
    
    if not success:
        sys.exit(1)
EOF

chmod +x "$DOWNLOAD_HELPER"

# 7. 创建健康检查脚本
HEALTH_CHECK="/home/user/machine/scripts/health-check.sh"
cat > "$HEALTH_CHECK" << 'EOF'
#!/bin/bash

# 系统健康检查脚本

echo "=== AI推理环境健康检查 ==="

# 检查虚拟环境
if [ -d "/home/user/machine/venv" ]; then
    echo "✅ 虚拟环境存在"
    source /home/user/machine/venv/bin/activate
    echo "Python: $(which python)"
    echo "Python版本: $(python --version)"
else
    echo "❌ 虚拟环境不存在"
    exit 1
fi

# 检查GPU
if command -v nvidia-smi > /dev/null 2>&1; then
    echo "✅ NVIDIA驱动已安装"
    echo "GPU信息:"
    nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader
else
    echo "⚠️  未检测到NVIDIA GPU"
fi

# 检查Python包
echo ""
echo "检查Python包安装情况:"

packages=("torch" "transformers" "modelscope" "vllm" "accelerate")
for package in "${packages[@]}"; do
    if python -c "import $package" 2>/dev/null; then
        version=$(python -c "import $package; print($package.__version__)" 2>/dev/null || echo "未知版本")
        echo "✅ $package: $version"
    else
        echo "❌ $package: 未安装"
    fi
done

# 检查CUDA
echo ""
echo "检查CUDA:"
python -c "
import torch
print(f'PyTorch CUDA可用: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'CUDA版本: {torch.version.cuda}')
    print(f'GPU数量: {torch.cuda.device_count()}')
"

# 检查服务端口
echo ""
echo "检查服务端口:"
if netstat -tuln | grep -q ":8000"; then
    echo "✅ 端口8000正在监听"
else
    echo "⚠️  端口8000未监听"
fi

# 检查vLLM服务
echo ""
echo "检查vLLM服务:"
if curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ vLLM服务运行正常"
else
    echo "⚠️  vLLM服务未运行或不健康"
fi

echo ""
echo "=== 健康检查完成 ==="
EOF

chmod +x "$HEALTH_CHECK"

echo ""
echo "=== 中国大陆网络环境优化配置完成 ==="
echo ""
echo "配置内容:"
echo "  ✅ pip镜像源: 阿里云"
echo "  ✅ Hugging Face镜像: hf-mirror.com"
echo "  ✅ 环境变量配置: /home/user/machine/.env"
echo "  ✅ 下载助手: $DOWNLOAD_HELPER"
echo "  ✅ 健康检查: $HEALTH_CHECK"
echo ""
echo "使用方法:"
echo "  1. 重新加载环境: source ~/.bashrc"
echo "  2. 激活AI环境: activate-ai"
echo "  3. 健康检查: ./scripts/health-check.sh"
echo "  4. 下载模型: python scripts/download-helper.py <model_id> <local_dir>"
echo ""
