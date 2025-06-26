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
TORCH_NPU_CHECK=$(python -c "
import sys
try:
    import torch_npu
    import torch
    print('CONFLICT: torch-npu and torch may have version conflicts')
    sys.exit(1)
except ImportError as e:
    if 'torch_npu' in str(e):
        print('OK: torch-npu not installed (避免冲突)')
    else:
        print('WARNING: torch may not be properly installed')
        sys.exit(1)
except Exception as e:
    print(f'ERROR: {e}')
    sys.exit(1)
" 2>/dev/null)

echo "  $TORCH_NPU_CHECK"

# 检查vLLM是否可以正常导入
VLLM_IMPORT_CHECK=$(python -c "
try:
    import vllm
    from vllm import LLM
    print('OK: vLLM can be imported successfully')
except ImportError as e:
    print(f'ERROR: vLLM import failed - {e}')
    exit(1)
except Exception as e:
    print(f'ERROR: vLLM check failed - {e}')
    exit(1)
" 2>&1)

if [[ $VLLM_IMPORT_CHECK == ERROR* ]]; then
    echo "❌ vLLM依赖检查失败:"
    echo "  $VLLM_IMPORT_CHECK"
    echo ""
    echo "建议解决方案："
    echo "  1. 检查是否存在torch-npu与torch冲突: pip list | grep torch"
    echo "  2. 如有冲突，卸载torch-npu: pip uninstall torch-npu"
    echo "  3. 重新安装vLLM: pip install vllm"
    exit 1
else
    echo "✅ $VLLM_IMPORT_CHECK"
fi

# 检查进程
PIDS=$(pgrep -f "vllm.entrypoints.openai.api_server" || true)
if [ -n "$PIDS" ]; then
    echo "✅ vLLM服务正在运行 (PID: $PIDS)"
else
    echo "❌ vLLM服务未运行"
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
