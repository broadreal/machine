#!/bin/bash

# vLLM 环境设置和问题修复脚本
# 这个脚本会自动检测并修复之前遇到的所有问题

set -e

echo "=== vLLM 环境设置和问题修复 ==="
echo "此脚本会检测并自动修复以下问题："
echo "  1. torch-npu 与 torch 的版本冲突"
echo "  2. vLLM 依赖缺失或损坏" 
echo "  3. 模型文件缺失"
echo "  4. 服务配置问题"
echo ""

# 配置变量
VENV_DIR="/home/user/machine/venv"
MODEL_PATH="/home/user/machine/models/Qwen/Qwen3-32B"
CONFIG_DIR="/home/user/machine/config"
LOG_DIR="/home/user/machine/logs"
LOG_FILE="$LOG_DIR/vllm-setup.log"

# 创建目录
mkdir -p "$LOG_DIR"
mkdir -p "$CONFIG_DIR"

# 步骤1：检查Python环境
echo "步骤1：检查Python环境..." | tee -a "$LOG_FILE"
if ! command -v python &> /dev/null; then
    echo "❌ Python 未找到" | tee -a "$LOG_FILE"
    exit 1
fi

python_version=$(python --version 2>&1)
echo "✅ $python_version" | tee -a "$LOG_FILE"

# 激活虚拟环境（如果存在）
if [ -d "$VENV_DIR" ]; then
    echo "✅ 激活虚拟环境: $VENV_DIR" | tee -a "$LOG_FILE"
    source "$VENV_DIR/bin/activate"
else
    echo "⚠️  虚拟环境不存在，使用系统Python" | tee -a "$LOG_FILE"
fi

# 步骤2：检查并修复依赖冲突  
echo ""
echo "步骤2：检查并修复依赖冲突..." | tee -a "$LOG_FILE"

# 检查torch-npu冲突
echo "检查torch-npu冲突..." | tee -a "$LOG_FILE"
if pip list | grep -q "torch-npu"; then
    echo "❌ 发现torch-npu，这会与vLLM冲突" | tee -a "$LOG_FILE"
    echo "正在卸载torch-npu..." | tee -a "$LOG_FILE"
    pip uninstall torch-npu -y 2>&1 | tee -a "$LOG_FILE"
    echo "✅ torch-npu已卸载" | tee -a "$LOG_FILE"
else
    echo "✅ 无torch-npu冲突" | tee -a "$LOG_FILE"
fi

# 步骤3：安装/验证vLLM
echo ""
echo "步骤3：安装/验证vLLM..." | tee -a "$LOG_FILE"

VLLM_CHECK=$(python -c "
try:
    import vllm
    from vllm import LLM
    from vllm.entrypoints.openai import api_server
    print(f'OK: vLLM {vllm.__version__} 已安装并可用')
except ImportError as e:
    print(f'ERROR: vLLM导入失败 - {e}')
    exit(1)
except Exception as e:
    print(f'ERROR: vLLM检查失败 - {e}')
    exit(1)
" 2>&1)

if [[ $VLLM_CHECK == ERROR* ]]; then
    echo "❌ vLLM不可用，正在安装..." | tee -a "$LOG_FILE"
    echo "$VLLM_CHECK" | tee -a "$LOG_FILE"
    
    # 使用国内镜像安装vLLM
    echo "使用阿里云镜像安装vLLM..." | tee -a "$LOG_FILE"
    if pip install vllm -i https://mirrors.aliyun.com/pypi/simple/ --upgrade 2>&1 | tee -a "$LOG_FILE"; then
        echo "✅ vLLM安装成功" | tee -a "$LOG_FILE"
    else
        echo "❌ vLLM安装失败，尝试官方源..." | tee -a "$LOG_FILE"
        pip install vllm --upgrade 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # 重新验证
    if python -c "import vllm; print('vLLM验证成功')" 2>/dev/null; then
        echo "✅ vLLM安装并验证成功" | tee -a "$LOG_FILE"
    else
        echo "❌ vLLM安装失败" | tee -a "$LOG_FILE"
        exit 1
    fi
else
    echo "✅ $VLLM_CHECK" | tee -a "$LOG_FILE"
fi

# 步骤4：检查计算平台
echo ""
echo "步骤4：检查计算平台..." | tee -a "$LOG_FILE"
python -c "
import torch
if torch.cuda.is_available():
    print(f'✅ CUDA可用，GPU数量: {torch.cuda.device_count()}')
    for i in range(torch.cuda.device_count()):
        gpu_name = torch.cuda.get_device_name(i)
        mem_gb = torch.cuda.get_device_properties(i).total_memory / 1024**3
        print(f'  GPU {i}: {gpu_name} ({mem_gb:.1f}GB)')
else:
    print('⚠️  CUDA不可用，将使用CPU模式（性能较低）')
" 2>&1 | tee -a "$LOG_FILE"

# 步骤5：检查模型
echo ""
echo "步骤5：检查模型文件..." | tee -a "$LOG_FILE"
if [ -d "$MODEL_PATH" ]; then
    echo "✅ 模型路径存在: $MODEL_PATH" | tee -a "$LOG_FILE"
    
    # 验证模型文件
    model_files_ok=true
    if [ -f "$MODEL_PATH/config.json" ]; then
        echo "✅ config.json 存在" | tee -a "$LOG_FILE"
    else
        echo "❌ config.json 缺失" | tee -a "$LOG_FILE"
        model_files_ok=false
    fi
    
    if [ -f "$MODEL_PATH/pytorch_model.bin" ] || [ -f "$MODEL_PATH/model.safetensors" ] || ls "$MODEL_PATH"/pytorch_model-*.bin 1> /dev/null 2>&1; then
        echo "✅ 模型权重文件存在" | tee -a "$LOG_FILE"
    else
        echo "❌ 模型权重文件缺失" | tee -a "$LOG_FILE"
        model_files_ok=false
    fi
    
    if [ "$model_files_ok" = false ]; then
        echo "⚠️  模型文件不完整，建议重新下载" | tee -a "$LOG_FILE"
    fi
else
    echo "❌ 模型不存在: $MODEL_PATH" | tee -a "$LOG_FILE"
    echo ""
    echo "是否自动下载模型？(y/N): "
    read -r download_model
    if [[ "$download_model" =~ ^[Yy]$ ]]; then
        echo "正在下载模型..." | tee -a "$LOG_FILE"
        if [ -f "scripts/download-model.sh" ]; then
            bash scripts/download-model.sh Qwen3-32B 2>&1 | tee -a "$LOG_FILE"
        else
            echo "❌ 下载脚本不存在" | tee -a "$LOG_FILE"
        fi
    else
        echo "⚠️  需要手动下载模型后才能启动服务" | tee -a "$LOG_FILE"
    fi
fi

# 步骤6：检查服务状态
echo ""
echo "步骤6：检查服务状态..." | tee -a "$LOG_FILE"
PORT=8000

# 检查端口是否被占用
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    OCCUPYING_PID=$(lsof -Pi :$PORT -sTCP:LISTEN -t)
    echo "⚠️  端口 $PORT 被占用 (PID: $OCCUPYING_PID)" | tee -a "$LOG_FILE"
    
    # 检查是否是vLLM进程
    if ps -p $OCCUPYING_PID -o cmd --no-headers | grep -q "vllm"; then
        echo "✅ vLLM服务正在运行" | tee -a "$LOG_FILE"
    else
        echo "❌ 端口被其他进程占用" | tee -a "$LOG_FILE"
        echo "占用进程: $(ps -p $OCCUPYING_PID -o cmd --no-headers)" | tee -a "$LOG_FILE"
    fi
else
    echo "✅ 端口 $PORT 可用" | tee -a "$LOG_FILE"
fi

# 步骤7：生成配置文件
echo ""
echo "步骤7：生成配置文件..." | tee -a "$LOG_FILE"

# 创建vLLM配置文件
cat > "$CONFIG_DIR/vllm-config.yml" << 'EOF'
# vLLM 服务配置
model:
  path: /home/user/machine/models/Qwen/Qwen3-32B
  tensor_parallel_size: 4
  gpu_memory_utilization: 0.8
  max_model_len: 4096
  trust_remote_code: true

server:
  host: "0.0.0.0"
  port: 8000
  
logging:
  level: "INFO"
  file: /home/user/machine/logs/vllm-service.log
EOF

echo "✅ 配置文件已创建: $CONFIG_DIR/vllm-config.yml" | tee -a "$LOG_FILE"

# 生成使用建议
echo ""
echo "=== 环境检查完成 ===" | tee -a "$LOG_FILE"
echo ""
echo "使用建议："
echo "  1. 检查环境: ./scripts/check-vllm.sh"
echo "  2. 启动服务: ./scripts/start-vllm.sh"
echo "  3. 下载模型: ./scripts/download-model.sh Qwen3-32B"
echo ""
echo "日志位置:"
echo "  设置日志: $LOG_FILE"
echo "  服务日志: $LOG_DIR/vllm-service.log"
echo "  下载日志: $LOG_DIR/model-download.log"
echo ""

# 检查是否需要重启终端
if pip list | grep -q torch && ! python -c "import torch" 2>/dev/null; then
    echo "⚠️  可能需要重启终端或重新激活虚拟环境"
fi

echo "环境设置完成！" | tee -a "$LOG_FILE"
