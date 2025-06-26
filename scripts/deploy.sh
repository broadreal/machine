#!/bin/bash

# 一键部署脚本
# 用法: ./deploy.sh [full|quick|help]

set -e

# 配置变量
LOG_DIR="/home/user/machine/logs"
LOG_FILE="$LOG_DIR/deploy.log"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 显示帮助
show_help() {
    echo "一键部署脚本"
    echo ""
    echo "用法: $0 [模式]"
    echo ""
    echo "模式:"
    echo "  full    - 完整部署（环境+模型+服务）"
    echo "  quick   - 快速部署（假设环境已就绪）"
    echo "  help    - 显示此帮助信息"
    echo ""
    echo "说明:"
    echo "  full模式会安装所有环境、下载模型并启动服务"
    echo "  quick模式只进行vLLM设置和启动服务"
    echo ""
}

# 检查脚本是否存在
check_scripts() {
    local scripts=("install-env.sh" "download-model.sh" "vllm.sh")
    
    for script in "${scripts[@]}"; do
        if [ ! -f "scripts/$script" ]; then
            log_error "脚本不存在: scripts/$script"
            return 1
        fi
    done
    
    log_info "所有必需脚本都存在"
    return 0
}

# 完整部署
deploy_full() {
    log "${BLUE}=== 完整部署模式 ===${NC}"
    
    # 1. 检查脚本
    log "步骤1: 检查脚本..."
    if ! check_scripts; then
        exit 1
    fi
    
    # 2. 安装环境
    log "步骤2: 安装环境..."
    if ! ./scripts/install-env.sh all; then
        log_error "环境安装失败"
        exit 1
    fi
    
    # 3. 下载模型
    log "步骤3: 下载模型..."
    echo "是否下载Qwen3-32B模型？这将需要约60GB存储空间 (y/N): "
    read -r download_model
    if [[ "$download_model" =~ ^[Yy]$ ]]; then
        if ! ./scripts/download-model.sh Qwen3-32B; then
            log_error "模型下载失败"
            exit 1
        fi
    else
        log_warn "跳过模型下载，需要手动下载模型"
    fi
    
    # 4. 设置vLLM
    log "步骤4: 设置vLLM..."
    if ! ./scripts/vllm.sh setup; then
        log_error "vLLM设置失败"
        exit 1
    fi
    
    # 5. 启动服务
    log "步骤5: 启动服务..."
    echo "是否现在启动vLLM服务？(y/N): "
    read -r start_service
    if [[ "$start_service" =~ ^[Yy]$ ]]; then
        log "正在启动vLLM服务..."
        echo "服务将在后台启动，请稍候..."
        nohup ./scripts/vllm.sh start > "$LOG_DIR/vllm-startup.log" 2>&1 &
        
        # 等待服务启动
        log "等待服务启动..."
        for i in {1..30}; do
            sleep 2
            if ./scripts/vllm.sh check &>/dev/null; then
                log_info "vLLM服务启动成功"
                break
            fi
            echo -n "."
        done
        
        if ! ./scripts/vllm.sh check &>/dev/null; then
            log_warn "服务启动可能需要更多时间，请稍后检查"
            echo "检查命令: ./scripts/vllm.sh status"
            echo "查看日志: tail -f $LOG_DIR/vllm-startup.log"
        fi
    else
        log "跳过服务启动，可以稍后运行: ./scripts/vllm.sh start"
    fi
    
    log_info "完整部署完成！"
}

# 快速部署
deploy_quick() {
    log "${BLUE}=== 快速部署模式 ===${NC}"
    
    # 1. 检查脚本
    if ! check_scripts; then
        exit 1
    fi
    
    # 2. 设置vLLM
    log "步骤1: 设置vLLM环境..."
    if ! ./scripts/vllm.sh setup; then
        log_error "vLLM设置失败"
        exit 1
    fi
    
    # 3. 启动服务
    log "步骤2: 启动vLLM服务..."
    echo "正在启动vLLM服务..."
    nohup ./scripts/vllm.sh start > "$LOG_DIR/vllm-startup.log" 2>&1 &
    
    # 等待服务启动
    log "等待服务启动..."
    for i in {1..30}; do
        sleep 2
        if ./scripts/vllm.sh check &>/dev/null; then
            log_info "vLLM服务启动成功"
            break
        fi
        echo -n "."
    done
    
    if ! ./scripts/vllm.sh check &>/dev/null; then
        log_warn "服务启动可能需要更多时间"
        echo "检查状态: ./scripts/vllm.sh status"
        echo "查看日志: tail -f $LOG_DIR/vllm-startup.log"
    fi
    
    log_info "快速部署完成！"
}

# 显示部署后信息
show_post_deploy_info() {
    echo ""
    echo "${GREEN}=== 部署完成 ===${NC}"
    echo ""
    echo "常用命令:"
    echo "  检查服务状态: ./scripts/vllm.sh status"
    echo "  停止服务:     ./scripts/vllm.sh stop"
    echo "  重启服务:     ./scripts/vllm.sh stop && ./scripts/vllm.sh start"
    echo ""
    echo "API访问:"
    echo "  服务地址:     http://localhost:8000"
    echo "  健康检查:     http://localhost:8000/health"
    echo "  模型列表:     http://localhost:8000/v1/models"
    echo ""
    echo "日志文件:"
    echo "  部署日志:     $LOG_FILE"
    echo "  服务日志:     $LOG_DIR/vllm-service.log"
    echo "  启动日志:     $LOG_DIR/vllm-startup.log"
    echo ""
    echo "故障排除:"
    echo "  如果服务无法访问，请检查:"
    echo "  1. 防火墙设置 (端口8000)"
    echo "  2. 服务日志中的错误信息"
    echo "  3. GPU内存是否足够"
    echo ""
}

# 主函数
main() {
    local mode=${1:-help}
    
    log "${BLUE}=== vLLM 一键部署脚本 ===${NC}"
    log "部署模式: $mode"
    log "开始时间: $(date)"
    
    case "$mode" in
        full)
            deploy_full
            show_post_deploy_info
            ;;
        quick)
            deploy_quick
            show_post_deploy_info
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "未知模式: $mode"
            echo ""
            show_help
            exit 1
            ;;
    esac
    
    log "结束时间: $(date)"
}

# 执行主函数
main "$@"
