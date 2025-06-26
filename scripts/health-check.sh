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
