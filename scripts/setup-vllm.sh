#!/bin/bash

# vLLM 安装和配置脚本

set -e

echo "=== vLLM 安装和配置脚本 ==="

# 配置变量
ENV_DIR="/home/user/machine/venv"
CONFIG_DIR="/home/user/machine/config"
LOG_FILE="/home/user/machine/logs/vllm-setup.log"

# 创建日志目录
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$CONFIG_DIR"

# 检查虚拟环境
if [ ! -d "$ENV_DIR" ]; then
    echo "❌ 虚拟环境不存在，请先运行 install-modelscope.sh"
    exit 1
fi

echo "开始安装vLLM..." | tee -a "$LOG_FILE"

# 激活虚拟环境
source "$ENV_DIR/bin/activate"

# 检查CUDA是否可用
echo "检查CUDA环境..." | tee -a "$LOG_FILE"
python -c "
import torch
print(f'PyTorch版本: {torch.__version__}')
print(f'CUDA是否可用: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'CUDA版本: {torch.version.cuda}')
    print(f'GPU数量: {torch.cuda.device_count()}')
    for i in range(torch.cuda.device_count()):
        print(f'GPU {i}: {torch.cuda.get_device_name(i)}')
        print(f'  显存: {torch.cuda.get_device_properties(i).total_memory / 1024**3:.1f} GB')
" 2>&1 | tee -a "$LOG_FILE"

# 安装vLLM
echo "安装vLLM..." | tee -a "$LOG_FILE"
pip install vllm 2>&1 | tee -a "$LOG_FILE"

# 验证vLLM安装
echo "验证vLLM安装..." | tee -a "$LOG_FILE"
python -c "
try:
    import vllm
    print('✅ vLLM安装成功！版本：', vllm.__version__)
except ImportError as e:
    print('❌ vLLM安装失败：', e)
    exit(1)
" 2>&1 | tee -a "$LOG_FILE"

# 创建vLLM配置文件
VLLM_CONFIG="$CONFIG_DIR/vllm-config.yml"
echo "创建vLLM配置文件：$VLLM_CONFIG" | tee -a "$LOG_FILE"

cat > "$VLLM_CONFIG" << 'EOF'
# vLLM 服务配置文件

# 模型配置
model:
  name: "Qwen3-32B"
  path: "/home/user/machine/models/Qwen/Qwen3-32B"
  trust_remote_code: true

# 服务配置
server:
  host: "0.0.0.0"
  port: 8000
  uvicorn_log_level: "info"

# 性能配置
performance:
  # GPU配置
  tensor_parallel_size: 4      # 多GPU并行，根据GPU数量调整
  gpu_memory_utilization: 0.8  # GPU内存使用率
  
  # 上下文配置
  max_model_len: 4096         # 最大上下文长度
  max_num_batched_tokens: 8192 # 批处理token数量
  
  # 推理配置
  temperature: 0.7
  top_p: 0.8
  max_tokens: 2048
  
  # 量化配置（可选）
  # quantization: "awq"        # 启用AWQ量化以节省显存
  # quantization_param_path: null

# 日志配置
logging:
  level: "INFO"
  disable_log_stats: false
  
# API配置
api:
  # OpenAI兼容API
  enable_openai_api: true
  openai_api_key: null
  
  # 自定义API前缀
  api_prefix: "/v1"
  
  # CORS配置
  cors_allow_origins: ["*"]
  cors_allow_methods: ["*"]
  cors_allow_headers: ["*"]

# 安全配置
security:
  disable_log_requests: false
  max_concurrent_requests: 100
EOF

# 创建启动脚本
START_SCRIPT="/home/user/machine/scripts/start-vllm.sh"
echo "创建vLLM启动脚本：$START_SCRIPT" | tee -a "$LOG_FILE"

cat > "$START_SCRIPT" << 'EOF'
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

# 检查环境
if [ ! -d "$ENV_DIR" ]; then
    echo "❌ 虚拟环境不存在"
    exit 1
fi

if [ ! -d "$MODEL_PATH" ]; then
    echo "❌ 模型不存在：$MODEL_PATH"
    exit 1
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
EOF

chmod +x "$START_SCRIPT"

# 创建停止脚本
STOP_SCRIPT="/home/user/machine/scripts/stop-vllm.sh"
echo "创建vLLM停止脚本：$STOP_SCRIPT" | tee -a "$LOG_FILE"

cat > "$STOP_SCRIPT" << 'EOF'
#!/bin/bash

# vLLM 服务停止脚本

echo "=== 停止vLLM服务 ==="

# 查找vLLM进程
PIDS=$(pgrep -f "vllm.entrypoints.openai.api_server" || true)

if [ -z "$PIDS" ]; then
    echo "没有发现运行中的vLLM服务"
    exit 0
fi

echo "发现vLLM进程：$PIDS"

# 优雅停止
echo "正在停止vLLM服务..."
kill $PIDS

# 等待进程结束
sleep 5

# 检查是否还在运行
REMAINING_PIDS=$(pgrep -f "vllm.entrypoints.openai.api_server" || true)
if [ -n "$REMAINING_PIDS" ]; then
    echo "强制停止vLLM服务..."
    kill -9 $REMAINING_PIDS
fi

echo "✅ vLLM服务已停止"
EOF

chmod +x "$STOP_SCRIPT"

# 创建服务检查脚本
CHECK_SCRIPT="/home/user/machine/scripts/check-vllm.sh"
echo "创建服务检查脚本：$CHECK_SCRIPT" | tee -a "$LOG_FILE"

cat > "$CHECK_SCRIPT" << 'EOF'
#!/bin/bash

# vLLM 服务检查脚本

echo "=== vLLM 服务状态检查 ==="

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
EOF

chmod +x "$CHECK_SCRIPT"

echo ""
echo "=== vLLM 安装配置完成 ==="
echo "✅ vLLM已成功安装并配置"
echo ""
echo "使用方法："
echo "1. 启动服务：./scripts/start-vllm.sh"
echo "2. 检查状态：./scripts/check-vllm.sh"
echo "3. 停止服务：./scripts/stop-vllm.sh"
echo ""
echo "配置文件："
echo "  - vLLM配置：$VLLM_CONFIG"
echo "  - 启动脚本：$START_SCRIPT"
echo ""
echo "API端点："
echo "  - Health: http://localhost:8000/health"
echo "  - Models: http://localhost:8000/v1/models"
echo "  - Chat: http://localhost:8000/v1/chat/completions"
echo ""
