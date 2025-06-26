#!/bin/bash

# vLLM 统一管理脚本
# 用法: ./vllm.sh [setup|start|stop|check|status|help]

set -e

# 配置变量
VENV_DIR="/home/user/machine/venv"
MODEL_PATH="/home/user/machine/models/Qwen/Qwen3-32B"
CONFIG_DIR="/home/user/machine/config"
LOG_DIR="/home/user/machine/logs"
LOG_FILE="$LOG_DIR/vllm.log"
PORT=8000

# 创建目录
mkdir -p "$LOG_DIR" "$CONFIG_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log_info() {
    log "${GREEN}✅ $1${NC}"
}

log_warn() {
    log "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    log "${RED}❌ $1${NC}"
}

# 显示帮助信息
show_help() {
    echo "vLLM 统一管理脚本"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  setup    - 设置vLLM环境并修复问题"
    echo "  start    - 启动vLLM服务"
    echo "  stop     - 停止vLLM服务"
    echo "  check    - 检查vLLM服务状态"
    echo "  status   - 显示详细状态信息"
    echo "  help     - 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 setup     # 首次安装和配置"
    echo "  $0 start     # 启动服务"
    echo "  $0 check     # 快速检查状态"
    echo ""
}

# 激活虚拟环境
activate_venv() {
    if [ -d "$VENV_DIR" ]; then
        log "激活虚拟环境: $VENV_DIR"
        source "$VENV_DIR/bin/activate"
        
        # 验证激活是否成功
        if [ "$VIRTUAL_ENV" = "$VENV_DIR" ]; then
            return 0
        else
            log_error "虚拟环境激活失败"
            return 1
        fi
    else
        log_error "虚拟环境不存在: $VENV_DIR"
        echo "请先运行: ./scripts/install-env.sh all"
        return 1
    fi
}

# 检查依赖冲突
check_dependencies() {
    log "检查依赖..."
    
    # 检查Python
    if ! command -v python &> /dev/null; then
        log_error "Python 未找到"
        return 1
    fi
    
    # 激活虚拟环境
    if ! activate_venv; then
        return 1
    fi
    
    # 检查torch-npu冲突
    if pip list | grep -q "torch-npu"; then
        log_error "发现torch-npu，这会与vLLM冲突"
        echo "正在自动修复..."
        pip uninstall torch-npu -y 2>&1 | tee -a "$LOG_FILE"
        log_info "torch-npu已卸载"
    fi
    
    # 检查vLLM
    local vllm_check=$(python -c "
try:
    import vllm
    from vllm import LLM
    from vllm.entrypoints.openai import api_server
    print(f'OK: vLLM {vllm.__version__} 可用')
except ImportError as e:
    print(f'ERROR: {e}')
    exit(1)
" 2>&1)
    
    if [[ $vllm_check == ERROR* ]]; then
        log_error "vLLM不可用: $vllm_check"
        return 1
    else
        log_info "$vllm_check"
    fi
    
    return 0
}

# 检查模型
check_model() {
    log "检查模型..."
    
    if [ ! -d "$MODEL_PATH" ]; then
        log_error "模型不存在: $MODEL_PATH"
        echo "请运行: ./download-model.sh Qwen3-32B"
        return 1
    fi
    
    # 检查关键文件
    local model_ok=true
    if [ ! -f "$MODEL_PATH/config.json" ]; then
        log_error "缺少 config.json"
        model_ok=false
    fi
    
    if [ ! -f "$MODEL_PATH/pytorch_model.bin" ] && [ ! -f "$MODEL_PATH/model.safetensors" ] && ! ls "$MODEL_PATH"/pytorch_model-*.bin 1> /dev/null 2>&1; then
        log_error "缺少模型权重文件"
        model_ok=false
    fi
    
    if [ "$model_ok" = true ]; then
        log_info "模型文件验证通过"
        return 0
    else
        log_warn "模型文件不完整，建议重新下载"
        return 1
    fi
}

# 检查服务状态
check_service() {
    local pids=$(pgrep -f "vllm.entrypoints.openai.api_server" || true)
    
    if [ -n "$pids" ]; then
        log_info "vLLM服务正在运行 (PID: $pids)"
        
        # 检查端口
        if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
            log_info "端口 $PORT 正在监听"
            
            # 检查API响应
            local health_check=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/health 2>/dev/null || echo "000")
            if [ "$health_check" = "200" ]; then
                log_info "API健康检查通过"
                return 0
            else
                log_warn "API健康检查失败 (HTTP: $health_check)"
                return 1
            fi
        else
            log_error "端口 $PORT 未监听"
            return 1
        fi
    else
        log_error "vLLM服务未运行"
        return 1
    fi
}

# 设置环境
setup_vllm() {
    log "${BLUE}=== vLLM 环境设置 ===${NC}"
    
    # 先检查虚拟环境是否存在
    if [ ! -d "$VENV_DIR" ]; then
        log_error "虚拟环境不存在: $VENV_DIR"
        echo "请先运行 install-env.sh 安装环境"
        exit 1
    fi
    
    # 激活虚拟环境
    if ! activate_venv; then
        exit 1
    fi
    
    # 在虚拟环境中检查Python
    if ! command -v python &> /dev/null; then
        log_error "Python 未安装或虚拟环境有问题"
        exit 1
    fi
    
    local python_version=$(python --version 2>&1)
    log_info "$python_version"
    
    # 检查并修复依赖
    if ! check_dependencies; then
        log "正在安装vLLM..."
        pip install vllm -i https://mirrors.aliyun.com/pypi/simple/ --upgrade 2>&1 | tee -a "$LOG_FILE"
        
        if ! check_dependencies; then
            log_error "vLLM安装失败"
            exit 1
        fi
    fi
    
    # 检查计算平台
    log "检查计算平台..."
    python -c "
import torch
if torch.cuda.is_available():
    print(f'✅ CUDA可用，GPU数量: {torch.cuda.device_count()}')
    for i in range(torch.cuda.device_count()):
        gpu_name = torch.cuda.get_device_name(i)
        mem_gb = torch.cuda.get_device_properties(i).total_memory / 1024**3
        print(f'  GPU {i}: {gpu_name} ({mem_gb:.1f}GB)')
else:
    print('⚠️  CUDA不可用，将使用CPU模式')
" 2>&1 | tee -a "$LOG_FILE"
    
    # 检查模型
    check_model || log_warn "模型检查失败，请手动下载模型"
    
    # 生成配置文件
    log "生成配置文件..."
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
    
    log_info "配置文件已创建: $CONFIG_DIR/vllm-config.yml"
    log_info "环境设置完成！"
}

# 启动服务
start_vllm() {
    log "${BLUE}=== 启动 vLLM 服务 ===${NC}"
    
    # 检查是否已经运行
    if check_service &>/dev/null; then
        log_warn "vLLM服务已在运行"
        return 0
    fi
    
    # 激活环境
    if ! activate_venv; then
        exit 1
    fi
    
    # 启动前检查
    if ! check_dependencies; then
        log_error "依赖检查失败，请运行: $0 setup"
        exit 1
    fi
    
    if ! check_model; then
        echo "是否继续启动？(y/N): "
        read -r continue_start
        if [[ ! "$continue_start" =~ ^[Yy]$ ]]; then
            log "取消启动"
            exit 1
        fi
    fi
    
    # 检查端口
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_error "端口 $PORT 已被占用"
        local pid=$(lsof -Pi :$PORT -sTCP:LISTEN -t)
        echo "占用进程: $(ps -p $pid -o cmd --no-headers)"
        exit 1
    fi
    
    log "启动vLLM服务..."
    log "模型路径: $MODEL_PATH"
    log "日志文件: $LOG_DIR/vllm-service.log"
    
    # 启动服务
    python -m vllm.entrypoints.openai.api_server \
        --model "$MODEL_PATH" \
        --host 0.0.0.0 \
        --port $PORT \
        --tensor-parallel-size 4 \
        --gpu-memory-utilization 0.8 \
        --max-model-len 4096 \
        --trust-remote-code \
        2>&1 | tee -a "$LOG_DIR/vllm-service.log"
}

# 停止服务
stop_vllm() {
    log "${BLUE}=== 停止 vLLM 服务 ===${NC}"
    
    local pids=$(pgrep -f "vllm.entrypoints.openai.api_server" || true)
    
    if [ -z "$pids" ]; then
        log_warn "vLLM服务未运行"
        return 0
    fi
    
    log "正在停止vLLM服务 (PID: $pids)..."
    
    # 优雅停止
    kill -TERM $pids 2>/dev/null || true
    
    # 等待5秒
    sleep 5
    
    # 检查是否还在运行
    if pgrep -f "vllm.entrypoints.openai.api_server" >/dev/null; then
        log_warn "优雅停止失败，强制终止..."
        pkill -KILL -f "vllm.entrypoints.openai.api_server" || true
    fi
    
    sleep 2
    
    if ! pgrep -f "vllm.entrypoints.openai.api_server" >/dev/null; then
        log_info "vLLM服务已停止"
    else
        log_error "服务停止失败"
        return 1
    fi
}

# 检查状态（简单）
check_vllm() {
    log "${BLUE}=== vLLM 服务检查 ===${NC}"
    
    if activate_venv && check_dependencies && check_service; then
        log_info "vLLM服务运行正常"
        return 0
    else
        log_error "vLLM服务存在问题"
        return 1
    fi
}

# 详细状态
status_vllm() {
    log "${BLUE}=== vLLM 详细状态 ===${NC}"
    
    # Python环境
    if command -v python &> /dev/null; then
        log_info "Python: $(python --version 2>&1)"
    else
        log_error "Python未找到"
    fi
    
    # 虚拟环境
    if [ -d "$VENV_DIR" ]; then
        log_info "虚拟环境: $VENV_DIR"
    else
        log_error "虚拟环境不存在"
    fi
    
    # 激活环境并检查
    if activate_venv; then
        # 依赖检查
        check_dependencies
        
        # 模型检查
        check_model
        
        # 服务状态
        check_service
        
        # 显示GPU信息
        log "GPU信息:"
        python -c "
import torch
if torch.cuda.is_available():
    for i in range(torch.cuda.device_count()):
        gpu_name = torch.cuda.get_device_name(i)
        mem_total = torch.cuda.get_device_properties(i).total_memory / 1024**3
        mem_reserved = torch.cuda.memory_reserved(i) / 1024**3
        mem_allocated = torch.cuda.memory_allocated(i) / 1024**3
        print(f'  GPU {i}: {gpu_name}')
        print(f'    总显存: {mem_total:.1f}GB')
        print(f'    已分配: {mem_allocated:.1f}GB')
        print(f'    已保留: {mem_reserved:.1f}GB')
else:
    print('  CUDA不可用')
" 2>&1 | tee -a "$LOG_FILE"
        
        # API信息
        if check_service &>/dev/null; then
            log "API信息:"
            echo "  地址: http://localhost:$PORT"
            echo "  健康检查: http://localhost:$PORT/health"
            echo "  模型列表: http://localhost:$PORT/v1/models"
        fi
    fi
    
    # 日志文件
    log "日志文件:"
    echo "  管理日志: $LOG_FILE"
    echo "  服务日志: $LOG_DIR/vllm-service.log"
}

# 主函数
main() {
    local command=${1:-help}
    
    case "$command" in
        setup)
            setup_vllm
            ;;
        start)
            start_vllm
            ;;
        stop)
            stop_vllm
            ;;
        check)
            check_vllm
            ;;
        status)
            status_vllm
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "未知命令: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
