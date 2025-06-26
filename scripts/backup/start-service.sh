#!/bin/bash

# 服务启动脚本（本地vLLM部署）

set -e

echo "=== 一体机AI服务启动脚本 ==="

# 配置变量
ENV_DIR="/home/user/machine/venv"
MODEL_PATH="/home/user/machine/models/Qwen/Qwen3-32B"
LOG_FILE="/home/user/machine/logs/service-start.log"

# 创建日志目录
mkdir -p "$(dirname "$LOG_FILE")"

# 检查虚拟环境
echo "检查Python虚拟环境..." | tee -a "$LOG_FILE"
if [ ! -d "$ENV_DIR" ]; then
    echo "❌ 虚拟环境不存在，请先运行 ./scripts/install-modelscope.sh" | tee -a "$LOG_FILE"
    exit 1
fi

echo "✅ 虚拟环境检查通过" | tee -a "$LOG_FILE"

# 检查模型文件
echo "检查模型文件..." | tee -a "$LOG_FILE"
if [ ! -d "$MODEL_PATH" ]; then
    echo "❌ 模型文件不存在：$MODEL_PATH" | tee -a "$LOG_FILE"
    echo "请先运行 ./scripts/download-model.sh" | tee -a "$LOG_FILE"
    exit 1
fi

echo "✅ 模型文件检查通过" | tee -a "$LOG_FILE"

# 检查端口占用
PORT=8000
echo "检查端口占用..." | tee -a "$LOG_FILE"
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  端口 $PORT 已被占用，正在停止现有服务..." | tee -a "$LOG_FILE"
    # 尝试停止现有的vLLM进程
    pkill -f "vllm.entrypoints.openai.api_server" 2>/dev/null || true
    sleep 5
    
    # 再次检查
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "❌ 端口 $PORT 仍被占用，请手动处理" | tee -a "$LOG_FILE"
        echo "可以使用：lsof -i :$PORT 查看占用进程" | tee -a "$LOG_FILE"
        exit 1
    fi
fi

echo "✅ 端口检查通过" | tee -a "$LOG_FILE"

# 检查GPU状态（如果有）
if command -v nvidia-smi > /dev/null 2>&1; then
    echo "检查GPU状态..." | tee -a "$LOG_FILE"
    GPU_COUNT=$(nvidia-smi --list-gpus | wc -l)
    echo "检测到 $GPU_COUNT 个GPU" | tee -a "$LOG_FILE"
    nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader | tee -a "$LOG_FILE"
else
    echo "⚠️  未检测到NVIDIA GPU，将使用CPU模式" | tee -a "$LOG_FILE"
fi

# 激活虚拟环境
echo "激活虚拟环境..." | tee -a "$LOG_FILE"
source "$ENV_DIR/bin/activate"

# 检查vLLM是否已安装
echo "检查vLLM安装..." | tee -a "$LOG_FILE"
if ! python -c "import vllm" 2>/dev/null; then
    echo "❌ vLLM未安装，请先运行 ./scripts/setup-vllm.sh" | tee -a "$LOG_FILE"
    exit 1
fi

echo "✅ vLLM检查通过" | tee -a "$LOG_FILE"

# 启动vLLM服务
echo "启动vLLM服务..." | tee -a "$LOG_FILE"
echo "这可能需要几分钟时间来加载模型，请耐心等待..." | tee -a "$LOG_FILE"

# 使用start-vllm.sh脚本启动服务
if [ -f "/home/user/machine/scripts/start-vllm.sh" ]; then
    echo "使用vLLM启动脚本..." | tee -a "$LOG_FILE"
    nohup /home/user/machine/scripts/start-vllm.sh >> "$LOG_FILE" 2>&1 &
    VLLM_PID=$!
    echo "vLLM服务已启动，PID: $VLLM_PID" | tee -a "$LOG_FILE"
else
    echo "直接启动vLLM服务..." | tee -a "$LOG_FILE"
    nohup python -m vllm.entrypoints.openai.api_server \
        --model "$MODEL_PATH" \
        --host 0.0.0.0 \
        --port $PORT \
        --tensor-parallel-size 4 \
        --gpu-memory-utilization 0.8 \
        --max-model-len 4096 \
        --trust-remote-code \
        >> "$LOG_FILE" 2>&1 &
    VLLM_PID=$!
    echo "vLLM服务已启动，PID: $VLLM_PID" | tee -a "$LOG_FILE"
fi

# 等待服务启动
echo "等待服务启动..." | tee -a "$LOG_FILE"
sleep 30

# 健康检查
MAX_RETRIES=20
RETRY_COUNT=0

echo "进行健康检查..." | tee -a "$LOG_FILE"
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/health 2>/dev/null || echo "000")
    
    if [ "$HEALTH_STATUS" = "200" ]; then
        echo "✅ 服务启动成功！" | tee -a "$LOG_FILE"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "等待服务启动... ($RETRY_COUNT/$MAX_RETRIES)" | tee -a "$LOG_FILE"
        sleep 15
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ 服务启动失败或超时" | tee -a "$LOG_FILE"
    echo "请检查日志：tail -f $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

echo ""
echo "=== 服务启动完成 ==="
echo "✅ AI服务已成功启动"
echo ""
echo "服务信息："
echo "  - API地址：http://localhost:8000"
echo "  - 健康检查：http://localhost:8000/health"
echo "  - 模型列表：http://localhost:8000/v1/models"
echo "  - OpenAI API：http://localhost:8000/v1/chat/completions"
echo ""
echo "管理命令："
echo "  - 检查状态：./scripts/check-vllm.sh"
echo "  - 停止服务：./scripts/stop-vllm.sh"
echo "  - 查看日志：tail -f $LOG_FILE"
echo ""
echo "进程信息："
echo "  - vLLM PID: $VLLM_PID"
echo "  - 日志文件：$LOG_FILE"
echo ""
