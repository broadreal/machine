#!/bin/bash

# vLLM 服务启动脚本

set -e

# 配置变量
ENV_DIR="/home/user/machine/venv"
MODEL_PATH="/home/user/machine/models/Qwen/Qwen3-32B"
CONFIG_FILE="/home/user/machine/config/vllm-config.yml"
LOG_FILE="/home/user/machine/logs/vllm-service.log"

# 创建日志目录
mkdir -p "$(dirname "$LOG_FILE")"

echo "=== vLLM 服务启动前检查 ==="

# 检查Python环境和vLLM依赖
echo "检查Python环境..."
if ! command -v python &> /dev/null; then
    echo "❌ Python 未安装或不在PATH中"
    exit 1
fi

# 检查vLLM依赖冲突
echo "检查vLLM依赖..."
VLLM_CHECK=$(python -c "
import sys
try:
    # 检查torch-npu与torch冲突
    try:
        import torch_npu
        import torch
        print('ERROR: torch-npu conflicts with torch, please uninstall torch-npu')
        sys.exit(1)
    except ImportError:
        pass  # torch-npu not installed is good
    
    # 检查vLLM是否可用
    import vllm
    from vllm import LLM
    print('OK: vLLM dependencies verified')
except ImportError as e:
    print(f'ERROR: vLLM import failed - {e}')
    sys.exit(1)
except Exception as e:
    print(f'ERROR: Dependency check failed - {e}')
    sys.exit(1)
" 2>&1)

if [[ $VLLM_CHECK == ERROR* ]]; then
    echo "❌ vLLM依赖检查失败:"
    echo "  $VLLM_CHECK"
    echo ""
    echo "解决方案："
    echo "  pip uninstall torch-npu  # 如果存在冲突"
    echo "  pip install vllm"
    exit 1
else
    echo "✅ $VLLM_CHECK"
fi

# 检查虚拟环境
if [ ! -d "$ENV_DIR" ]; then
    echo "❌ 虚拟环境不存在：$ENV_DIR"
    exit 1
else
    echo "✅ 虚拟环境存在：$ENV_DIR"
fi

# 检查模型路径
if [ ! -d "$MODEL_PATH" ]; then
    echo "❌ 模型不存在：$MODEL_PATH"
    echo ""
    echo "解决方案："
    echo "  1. 手动下载模型到指定路径"
    echo "  2. 运行模型下载脚本："
    echo "     bash /home/user/machine/scripts/download-model.sh Qwen3-32B"
    echo "  3. 修改启动脚本使用其他已存在的模型"
    exit 1
else
    echo "✅ 模型路径存在：$MODEL_PATH"
    # 检查模型文件完整性
    if [ ! -f "$MODEL_PATH/config.json" ]; then
        echo "⚠️  模型可能不完整：缺少 config.json"
    fi
    if [ ! -f "$MODEL_PATH/pytorch_model.bin" ] && [ ! -f "$MODEL_PATH/model.safetensors" ]; then
        echo "⚠️  模型可能不完整：缺少模型权重文件"
    fi
fi

echo "=== 启动vLLM服务 ==="
echo "模型路径：$MODEL_PATH"
echo "配置文件：$CONFIG_FILE"
echo "日志文件：$LOG_FILE"

# 激活虚拟环境
source "$ENV_DIR/bin/activate"

# 检查端口是否被占用
PORT=8000
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null; then
    echo "❌ 端口 $PORT 已被占用"
    echo "正在使用端口的进程："
    lsof -Pi :$PORT -sTCP:LISTEN
    exit 1
fi

# 启动vLLM服务
echo "启动vLLM服务..."
echo "请等待模型加载完成（可能需要几分钟）..."

python -m vllm.entrypoints.openai.api_server \
    --model "$MODEL_PATH" \
    --host 0.0.0.0 \
    --port $PORT \
    --tensor-parallel-size 4 \
    --gpu-memory-utilization 0.8 \
    --max-model-len 4096 \
    --trust-remote-code \
    2>&1 | tee -a "$LOG_FILE"
