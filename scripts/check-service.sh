#!/bin/bash

# 服务状态检查脚本（本地vLLM部署）

echo "=== AI服务状态检查 ==="

# 配置变量
API_URL="http://localhost:8000"
ENV_DIR="/home/user/machine/venv"
MODEL_PATH="/home/user/machine/models/Qwen/Qwen3-32B"

# 检查虚拟环境
echo "1. Python虚拟环境："
if [ -d "$ENV_DIR" ]; then
    echo "   ✅ 虚拟环境存在：$ENV_DIR"
    if [ -f "$ENV_DIR/bin/python" ]; then
        PYTHON_VERSION=$("$ENV_DIR/bin/python" --version 2>&1)
        echo "   Python版本：$PYTHON_VERSION"
    fi
else
    echo "   ❌ 虚拟环境不存在：$ENV_DIR"
fi

# 检查模型文件
echo ""
echo "2. 模型文件："
if [ -d "$MODEL_PATH" ]; then
    echo "   ✅ 模型文件存在：$MODEL_PATH"
    MODEL_SIZE=$(du -sh "$MODEL_PATH" 2>/dev/null | cut -f1)
    echo "   模型大小：$MODEL_SIZE"
else
    echo "   ❌ 模型文件不存在：$MODEL_PATH"
fi

# 检查vLLM进程
echo ""
echo "3. vLLM进程状态："
VLLM_PIDS=$(pgrep -f "vllm.entrypoints.openai.api_server" || true)
if [ -n "$VLLM_PIDS" ]; then
    echo "   ✅ vLLM进程正在运行"
    for pid in $VLLM_PIDS; do
        if ps -p $pid > /dev/null 2>&1; then
            PROCESS_INFO=$(ps -p $pid -o pid,ppid,user,etime,cmd --no-headers)
            echo "   PID: $pid"
            echo "   详情: $PROCESS_INFO"
        fi
    done
else
    echo "   ❌ vLLM进程未运行"
fi

# 检查端口监听
echo ""
echo "4. 端口监听状态："
if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "   ✅ 端口 8000 正在监听"
    PORT_INFO=$(lsof -Pi :8000 -sTCP:LISTEN | tail -n +2)
    echo "   端口信息："
    echo "$PORT_INFO" | sed 's/^/     /'
else
    echo "   ❌ 端口 8000 未监听"
fi

# 检查API健康状态
echo ""
echo "5. API健康检查："
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health" 2>/dev/null || echo "000")

if [ "$HEALTH_STATUS" = "200" ]; then
    echo "   ✅ API健康检查通过"
    
    # 获取详细健康信息
    HEALTH_DETAIL=$(curl -s "$API_URL/health" 2>/dev/null || echo "null")
    if [ "$HEALTH_DETAIL" != "null" ] && [ "$HEALTH_DETAIL" != "" ]; then
        echo "   健康详情: $HEALTH_DETAIL"
    fi
else
    echo "   ❌ API健康检查失败 (HTTP: $HEALTH_STATUS)"
fi

# 检查模型列表
echo ""
echo "6. 模型信息："
if [ "$HEALTH_STATUS" = "200" ]; then
    MODEL_INFO=$(curl -s "$API_URL/v1/models" 2>/dev/null || echo "null")
    if [ "$MODEL_INFO" != "null" ] && [ "$MODEL_INFO" != "" ]; then
        echo "   ✅ 模型加载成功"
        echo "$MODEL_INFO" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'data' in data:
        for model in data['data']:
            print(f'     - 模型: {model.get(\"id\", \"未知\")}')
            print(f'       类型: {model.get(\"object\", \"未知\")}')
            if 'created' in model:
                import datetime
                created_time = datetime.datetime.fromtimestamp(model['created'])
                print(f'       创建时间: {created_time}')
except:
    print('     解析模型信息失败')
" 2>/dev/null || echo "     无法解析模型信息"
    else
        echo "   ❌ 无法获取模型信息"
    fi
else
    echo "   ⏳ API未就绪，跳过模型检查"
fi

# 检查GPU使用情况（如果有）
echo ""
echo "7. GPU状态："
if command -v nvidia-smi > /dev/null 2>&1; then
    echo "   GPU信息："
    nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu,temperature.gpu --format=csv,noheader,nounits | \
    awk -F', ' '{printf "   GPU %s: %s\n     内存: %s/%s MB (%.1f%%) | 使用率: %s%% | 温度: %s°C\n", $1, $2, $3, $4, ($3/$4)*100, $5, $6}'
    
    # 检查是否有GPU进程
    GPU_PROCESSES=$(nvidia-smi --query-compute-apps=pid,name,used_memory --format=csv,noheader,nounits 2>/dev/null || echo "")
    if [ -n "$GPU_PROCESSES" ]; then
        echo "   GPU进程："
        echo "$GPU_PROCESSES" | awk -F', ' '{printf "     PID %s: %s (内存: %s MB)\n", $1, $2, $3}'
    fi
else
    echo "   ℹ️  未检测到NVIDIA GPU"
fi

# 系统资源使用情况
echo ""
echo "8. 系统资源："

# CPU使用率
if command -v top > /dev/null 2>&1; then
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' 2>/dev/null || echo "未知")
    echo "   CPU使用率: $CPU_USAGE"
fi

# 内存使用
if command -v free > /dev/null 2>&1; then
    MEMORY_INFO=$(free -h | awk '/^Mem:/ {printf "%s/%s (%.1f%%)", $3, $2, ($3/$2)*100}' 2>/dev/null || echo "未知")
    echo "   内存使用: $MEMORY_INFO"
fi

# 磁盘使用
DISK_USAGE=$(df -h /home/user/machine 2>/dev/null | awk 'NR==2 {printf "%s/%s (%s)", $3, $2, $5}' || echo "未知")
echo "   磁盘使用: $DISK_USAGE"

# 检查最近错误日志
echo ""
echo "9. 最近错误日志："
LOG_FILES=(
    "/home/user/machine/logs/vllm-service.log"
    "/home/user/machine/logs/service-start.log"
    "/home/user/machine/logs/deployment.log"
)

ERROR_FOUND=false
for log_file in "${LOG_FILES[@]}"; do
    if [ -f "$log_file" ]; then
        ERROR_COUNT=$(grep -i "error\|exception\|failed\|traceback" "$log_file" 2>/dev/null | wc -l || echo "0")
        if [ "$ERROR_COUNT" -gt 0 ]; then
            echo "   ⚠️  $log_file: 发现 $ERROR_COUNT 条错误"
            echo "   最近错误："
            grep -i "error\|exception\|failed" "$log_file" 2>/dev/null | tail -3 | sed 's/^/     /' || true
            ERROR_FOUND=true
        fi
    fi
done

if [ "$ERROR_FOUND" = false ]; then
    echo "   ✅ 未发现明显错误"
fi

# 性能测试
echo ""
echo "10. 简单性能测试："
if [ "$HEALTH_STATUS" = "200" ]; then
    echo "    正在发送测试请求..."
    TEST_START=$(date +%s.%N)
    
    TEST_RESPONSE=$(curl -s -X POST "$API_URL/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "Qwen3-32B",
            "messages": [{"role": "user", "content": "Hello"}],
            "max_tokens": 10,
            "temperature": 0.1
        }' 2>/dev/null || echo "null")
    
    TEST_END=$(date +%s.%N)
    
    if command -v bc > /dev/null 2>&1; then
        TEST_TIME=$(echo "$TEST_END - $TEST_START" | bc -l 2>/dev/null || echo "0")
    else
        TEST_TIME="0"
    fi
    
    if [ "$TEST_RESPONSE" != "null" ] && echo "$TEST_RESPONSE" | grep -q "choices"; then
        echo "    ✅ API响应正常 (耗时: ${TEST_TIME}s)"
        # 提取响应内容
        RESPONSE_CONTENT=$(echo "$TEST_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'choices' in data and len(data['choices']) > 0:
        content = data['choices'][0]['message']['content']
        print(f'响应内容: {content[:50]}...' if len(content) > 50 else f'响应内容: {content}')
except:
    pass
" 2>/dev/null || echo "")
        if [ -n "$RESPONSE_CONTENT" ]; then
            echo "    $RESPONSE_CONTENT"
        fi
    else
        echo "    ❌ API响应异常"
        if [ "$TEST_RESPONSE" != "null" ]; then
            echo "    错误信息: $(echo "$TEST_RESPONSE" | head -c 200)..."
        fi
    fi
else
    echo "    ⏳ 跳过性能测试（API未就绪）"
fi

echo ""
echo "=== 检查完成 ==="

# 提供常用命令
echo ""
echo "常用管理命令："
echo "  启动服务:     ./scripts/start-vllm.sh"
echo "  停止服务:     ./scripts/stop-vllm.sh"
echo "  查看实时日志: tail -f /home/user/machine/logs/vllm-service.log"
echo "  重启服务:     ./scripts/stop-vllm.sh && ./scripts/start-vllm.sh"
echo "  查看进程:     ps aux | grep vllm"
echo "  监控GPU:      watch -n 1 nvidia-smi"
echo ""
