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
import subprocess
import pkg_resources

def check_dependencies():
    try:
        # 检查torch-npu冲突
        try:
            result = subprocess.run(['pip', 'list'], capture_output=True, text=True)
            if 'torch-npu' in result.stdout:
                print('ERROR: torch-npu detected - conflicts with vLLM')
                print('  Solution: pip uninstall torch-npu')
                return False
        except:
            pass
        
        # 检查关键依赖
        import torch
        print(f'OK: torch {torch.__version__}')
        
        import vllm
        print(f'OK: vLLM {vllm.__version__}')
        
        # 检查vLLM核心组件
        from vllm import LLM
        from vllm.entrypoints.openai import api_server
        print('OK: vLLM components verified')
        
        # 检查CUDA/计算平台
        if torch.cuda.is_available():
            print(f'OK: CUDA available ({torch.cuda.device_count()} GPUs)')
        else:
            print('WARNING: CUDA not available, using CPU mode')
        
        return True
        
    except ImportError as e:
        print(f'ERROR: Import failed - {e}')
        print('  Solution: pip install vllm')
        return False
    except Exception as e:
        print(f'ERROR: Dependency check failed - {e}')
        return False

if not check_dependencies():
    sys.exit(1)
" 2>&1)

if [[ $VLLM_CHECK == *ERROR* ]]; then
    echo "❌ vLLM依赖检查失败:"
    echo "$VLLM_CHECK"
    echo ""
    echo "自动修复选项:"
    echo "  1. 自动卸载torch-npu并重新安装vLLM? (y/n)"
    read -r auto_fix
    if [[ "$auto_fix" =~ ^[Yy]$ ]]; then
        echo "正在修复依赖问题..."
        pip uninstall torch-npu -y 2>/dev/null || true
        pip install vllm -i https://mirrors.aliyun.com/pypi/simple/
        echo "依赖修复完成，请重新运行此脚本"
    fi
    exit 1
else
    echo "✅ vLLM依赖验证通过"
    echo "$VLLM_CHECK" | grep "OK:"
fi

# 检查虚拟环境
if [ ! -d "$ENV_DIR" ]; then
    echo "❌ 虚拟环境不存在：$ENV_DIR"
    exit 1
else
    echo "✅ 虚拟环境存在：$ENV_DIR"
fi

# 检查并验证模型路径
echo "检查模型..."
if [ ! -d "$MODEL_PATH" ]; then
    echo "❌ 模型不存在：$MODEL_PATH"
    echo ""
    echo "可用的解决方案："
    echo "  1. 自动下载模型 (推荐)"
    echo "  2. 手动指定其他模型路径"
    echo "  3. 退出并手动下载"
    echo ""
    echo "选择操作 (1/2/3): "
    read -r choice
    
    case "$choice" in
        1)
            echo "正在下载模型..."
            if [ -f "/home/user/machine/scripts/download-model.sh" ]; then
                bash /home/user/machine/scripts/download-model.sh Qwen3-32B
                if [ $? -eq 0 ] && [ -d "$MODEL_PATH" ]; then
                    echo "✅ 模型下载完成"
                else
                    echo "❌ 模型下载失败"
                    exit 1
                fi
            else
                echo "❌ 下载脚本不存在"
                exit 1
            fi
            ;;
        2)
            echo "请输入模型路径："
            read -r custom_model_path
            if [ -d "$custom_model_path" ]; then
                MODEL_PATH="$custom_model_path"
                echo "✅ 使用自定义模型路径：$MODEL_PATH"
            else
                echo "❌ 指定的模型路径不存在"
                exit 1
            fi
            ;;
        3)
            echo "请先下载模型后再运行此脚本"
            echo "  bash /home/user/machine/scripts/download-model.sh Qwen3-32B"
            exit 1
            ;;
        *)
            echo "无效选择，退出"
            exit 1
            ;;
    esac
else
    echo "✅ 模型路径存在：$MODEL_PATH"
fi

# 验证模型文件完整性
echo "验证模型文件..."
model_valid=true

if [ ! -f "$MODEL_PATH/config.json" ]; then
    echo "❌ 缺少配置文件：config.json"
    model_valid=false
fi

# 检查模型权重文件
if [ ! -f "$MODEL_PATH/pytorch_model.bin" ] && [ ! -f "$MODEL_PATH/model.safetensors" ] && [ ! -f "$MODEL_PATH/pytorch_model-00001-of-*.bin" ]; then
    echo "❌ 缺少模型权重文件"
    model_valid=false
fi

if [ ! -f "$MODEL_PATH/tokenizer.json" ] && [ ! -f "$MODEL_PATH/tokenizer_config.json" ]; then
    echo "❌ 缺少tokenizer文件"
    model_valid=false
fi

if [ "$model_valid" = false ]; then
    echo ""
    echo "模型文件不完整，建议重新下载："
    echo "  bash /home/user/machine/scripts/download-model.sh Qwen3-32B"
    echo ""
    echo "是否继续启动? (y/N): "
    read -r continue_anyway
    if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
        echo "退出启动"
        exit 1
    fi
else
    echo "✅ 模型文件验证通过"
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
