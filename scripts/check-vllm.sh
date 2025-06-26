#!/bin/bash

# vLLM 服务检查脚本

echo "=== vLLM 服务状态检查 ==="

# 检查Python环境和依赖
echo "检查Python环境和依赖..."
if ! command -v python &> /dev/null; then
    echo "❌ Python 未安装或不在PATH中"
    exit 1
fi

# 检查vLLM依赖冲突
echo "检查vLLM依赖..."
DEPENDENCY_CHECK=$(python -c "
import sys
import subprocess

def check_package_conflicts():
    try:
        # 检查torch-npu是否存在
        result = subprocess.run(['pip', 'list'], capture_output=True, text=True)
        pip_list = result.stdout
        
        has_torch_npu = 'torch-npu' in pip_list
        has_torch = 'torch' in pip_list and 'torch-npu' not in pip_list.split('torch')[1].split('\n')[0]
        
        if has_torch_npu:
            print('ERROR: torch-npu detected, this may conflict with vLLM')
            print('  Solution: pip uninstall torch-npu')
            return False
            
        if not has_torch:
            print('WARNING: torch not found in pip list')
            return False
            
        # 尝试导入vLLM核心组件
        import torch
        print(f'OK: torch {torch.__version__} available')
        
        import vllm
        print(f'OK: vLLM {vllm.__version__} available')
        
        from vllm import LLM
        from vllm.entrypoints.openai import api_server
        print('OK: vLLM core components can be imported')
        
        return True
        
    except ImportError as e:
        print(f'ERROR: Import failed - {e}')
        return False
    except Exception as e:
        print(f'ERROR: Dependency check failed - {e}')
        return False

if not check_package_conflicts():
    sys.exit(1)
" 2>&1)

if [[ $DEPENDENCY_CHECK == *ERROR* ]]; then
    echo "❌ 依赖检查失败:"
    echo "$DEPENDENCY_CHECK"
    echo ""
    echo "建议解决方案："
    echo "  1. 卸载冲突包: pip uninstall torch-npu"
    echo "  2. 重新安装vLLM: pip install vllm"
    echo "  3. 验证安装: python -c 'import vllm; print(vllm.__version__)'"
    exit 1
else
    echo "✅ 依赖检查通过"
    echo "$DEPENDENCY_CHECK" | grep "OK:"
fi

# 检查模型和服务状态
echo ""
echo "检查模型和服务..."

# 定义预期的模型路径
EXPECTED_MODEL_PATH="/home/user/machine/models/Qwen/Qwen3-32B"

# 检查模型是否存在
if [ ! -d "$EXPECTED_MODEL_PATH" ]; then
    echo "❌ 预期模型不存在: $EXPECTED_MODEL_PATH"
    echo "   请运行: ./scripts/download-model.sh Qwen3-32B"
    echo ""
fi

# 检查进程
PIDS=$(pgrep -f "vllm.entrypoints.openai.api_server" || true)
if [ -n "$PIDS" ]; then
    echo "✅ vLLM服务正在运行 (PID: $PIDS)"
    
    # 获取运行时使用的模型路径
    RUNNING_MODEL=$(ps -fp $PIDS | grep -o '\-\-model [^ ]*' | cut -d' ' -f2 || echo "unknown")
    if [ "$RUNNING_MODEL" != "unknown" ]; then
        echo "   使用模型: $RUNNING_MODEL"
        if [ "$RUNNING_MODEL" != "$EXPECTED_MODEL_PATH" ]; then
            echo "   ⚠️  运行模型与预期不符"
        fi
    fi
else
    echo "❌ vLLM服务未运行"
    if [ -d "$EXPECTED_MODEL_PATH" ]; then
        echo "   模型存在，可以启动服务: ./scripts/start-vllm.sh"
    else
        echo "   需要先下载模型: ./scripts/download-model.sh Qwen3-32B"
    fi
    echo ""
    echo "如需查看启动日志:"
    echo "   tail -f /home/user/machine/logs/vllm-service.log"
    exit 1
fi

# 检查端口
PORT=8000
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null; then
    echo "✅ 端口 $PORT 正在监听"
else
    echo "❌ 端口 $PORT 未监听"
    exit 1
fi

# 检查API响应
echo "检查API响应..."
HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/health || echo "000")

if [ "$HEALTH_CHECK" = "200" ]; then
    echo "✅ API健康检查通过"
else
    echo "❌ API健康检查失败 (HTTP: $HEALTH_CHECK)"
fi

# 显示模型信息（如果API可用）
if [ "$HEALTH_CHECK" = "200" ]; then
    echo ""
    echo "模型信息："
    curl -s http://localhost:$PORT/v1/models | python -m json.tool 2>/dev/null || echo "无法获取模型信息"
fi

echo ""
echo "日志文件："
echo "  /home/user/machine/logs/vllm-service.log"
