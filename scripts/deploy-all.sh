#!/bin/bash

# 一体机AI服务一键部署脚本

set -e

echo "================================================================"
echo "    一体机AI服务一键部署脚本"
echo "    包含: Docker + ModelScope + vLLM + Qwen3-32B"
echo "================================================================"

# 配置变量
SCRIPT_DIR="/home/user/machine/scripts"
LOG_DIR="/home/user/machine/logs"
MAIN_LOG="$LOG_DIR/deployment.log"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 记录开始时间
START_TIME=$(date)
echo "部署开始时间: $START_TIME" | tee -a "$MAIN_LOG"

# 检查系统要求
check_requirements() {
    echo ""
    echo "=== 检查系统要求 ===" | tee -a "$MAIN_LOG"
    
    # 检查操作系统
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "操作系统: $NAME $VERSION" | tee -a "$MAIN_LOG"
    fi
    
    # 检查Python版本
    if command -v python3 > /dev/null 2>&1; then
        PYTHON_VERSION=$(python3 --version 2>&1)
        echo "Python版本: $PYTHON_VERSION" | tee -a "$MAIN_LOG"
    else
        echo "❌ Python3 未安装" | tee -a "$MAIN_LOG"
        exit 1
    fi
    
    # 检查可用空间
    AVAILABLE_SPACE=$(df /home/user/machine | tail -1 | awk '{print $4}')
    REQUIRED_SPACE=$((100 * 1024 * 1024)) # 100GB in KB
    
    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        echo "❌ 磁盘空间不足！需要至少100GB，当前可用: $(($AVAILABLE_SPACE/1024/1024))GB" | tee -a "$MAIN_LOG"
        exit 1
    fi
    
    echo "✅ 可用磁盘空间: $(($AVAILABLE_SPACE/1024/1024))GB" | tee -a "$MAIN_LOG"
    
    # 检查内存
    TOTAL_MEM=$(free -g | awk '/^Mem:/ {print $2}')
    if [ "$TOTAL_MEM" -lt 32 ]; then
        echo "⚠️  内存可能不足：${TOTAL_MEM}GB (推荐64GB+)" | tee -a "$MAIN_LOG"
    else
        echo "✅ 系统内存: ${TOTAL_MEM}GB" | tee -a "$MAIN_LOG"
    fi
    
    # 检查GPU
    if command -v nvidia-smi > /dev/null 2>&1; then
        echo "✅ 检测到NVIDIA GPU" | tee -a "$MAIN_LOG"
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | tee -a "$MAIN_LOG"
    else
        echo "⚠️  未检测到NVIDIA GPU，将使用CPU推理（性能较慢）" | tee -a "$MAIN_LOG"
    fi
}

# 步骤1: 安装Docker
install_docker() {
    echo ""
    echo "=== 步骤1: 安装Docker ===" | tee -a "$MAIN_LOG"
    
    if command -v docker > /dev/null 2>&1; then
        echo "Docker已安装，跳过安装步骤" | tee -a "$MAIN_LOG"
        docker --version | tee -a "$MAIN_LOG"
    else
        echo "开始安装Docker..." | tee -a "$MAIN_LOG"
        bash "$SCRIPT_DIR/install-docker.sh" 2>&1 | tee -a "$MAIN_LOG"
        
        if [ $? -eq 0 ]; then
            echo "✅ Docker安装成功" | tee -a "$MAIN_LOG"
        else
            echo "❌ Docker安装失败" | tee -a "$MAIN_LOG"
            exit 1
        fi
    fi
}

# 步骤2: 安装ModelScope
install_modelscope() {
    echo ""
    echo "=== 步骤2: 安装ModelScope ===" | tee -a "$MAIN_LOG"
    echo "开始安装ModelScope..." | tee -a "$MAIN_LOG"
    
    bash "$SCRIPT_DIR/install-modelscope.sh" 2>&1 | tee -a "$MAIN_LOG"
    
    if [ $? -eq 0 ]; then
        echo "✅ ModelScope安装成功" | tee -a "$MAIN_LOG"
    else
        echo "❌ ModelScope安装失败" | tee -a "$MAIN_LOG"
        exit 1
    fi
}

# 步骤3: 下载模型
download_model() {
    echo ""
    echo "=== 步骤3: 下载Qwen3-32B模型 ===" | tee -a "$MAIN_LOG"
    echo "开始下载模型（这可能需要较长时间）..." | tee -a "$MAIN_LOG"
    
    bash "$SCRIPT_DIR/download-model.sh" 2>&1 | tee -a "$MAIN_LOG"
    
    if [ $? -eq 0 ]; then
        echo "✅ 模型下载成功" | tee -a "$MAIN_LOG"
    else
        echo "❌ 模型下载失败" | tee -a "$MAIN_LOG"
        exit 1
    fi
}

# 步骤4: 设置vLLM
setup_vllm() {
    echo ""
    echo "=== 步骤4: 设置vLLM ===" | tee -a "$MAIN_LOG"
    echo "开始设置vLLM..." | tee -a "$MAIN_LOG"
    
    bash "$SCRIPT_DIR/setup-vllm.sh" 2>&1 | tee -a "$MAIN_LOG"
    
    if [ $? -eq 0 ]; then
        echo "✅ vLLM设置成功" | tee -a "$MAIN_LOG"
    else
        echo "❌ vLLM设置失败" | tee -a "$MAIN_LOG"
        exit 1
    fi
}

# 步骤5: 启动vLLM服务（本地部署）
start_vllm_service() {
    echo ""
    echo "=== 步骤5: 启动vLLM服务 ===" | tee -a "$MAIN_LOG"
    echo "开始启动本地vLLM服务..." | tee -a "$MAIN_LOG"
    
    # 使用start-vllm.sh而不是start-service.sh
    if [ -f "$SCRIPT_DIR/start-vllm.sh" ]; then
        bash "$SCRIPT_DIR/start-vllm.sh" 2>&1 | tee -a "$MAIN_LOG"
    else
        # 备用启动方法
        bash "$SCRIPT_DIR/start-service.sh" 2>&1 | tee -a "$MAIN_LOG"
    fi
    
    if [ $? -eq 0 ]; then
        echo "✅ vLLM服务启动成功" | tee -a "$MAIN_LOG"
    else
        echo "❌ vLLM服务启动失败" | tee -a "$MAIN_LOG"
        exit 1
    fi
}

# 最终验证
final_verification() {
    echo ""
    echo "=== 最终验证 ===" | tee -a "$MAIN_LOG"
    echo "进行最终服务验证..." | tee -a "$MAIN_LOG"
    
    bash "$SCRIPT_DIR/check-service.sh" 2>&1 | tee -a "$MAIN_LOG"
}

# 主函数
main() {
    echo "开始自动化部署流程..." | tee -a "$MAIN_LOG"
    
    # 检查所有脚本是否存在
    REQUIRED_SCRIPTS=(
        "$SCRIPT_DIR/install-docker.sh"
        "$SCRIPT_DIR/install-modelscope.sh"
        "$SCRIPT_DIR/download-model.sh"
        "$SCRIPT_DIR/setup-vllm.sh"
        "$SCRIPT_DIR/start-service.sh"
        "$SCRIPT_DIR/check-service.sh"
    )
    
    for script in "${REQUIRED_SCRIPTS[@]}"; do
        if [ ! -f "$script" ]; then
            echo "❌ 脚本不存在: $script" | tee -a "$MAIN_LOG"
            exit 1
        fi
        chmod +x "$script"
    done
    
    # 执行部署步骤
    check_requirements
    install_docker
    install_modelscope
    download_model
    setup_vllm
    start_vllm_service
    final_verification
    
    # 记录完成时间
    END_TIME=$(date)
    echo ""
    echo "================================================================"
    echo "                    部署完成！"
    echo "================================================================"
    echo "开始时间: $START_TIME"
    echo "结束时间: $END_TIME"
    echo ""
    echo "🎉 一体机AI服务已成功部署！"
    echo ""
    echo "服务地址: http://localhost:8000"
    echo "API文档: http://localhost:8000/docs"
    echo "健康检查: http://localhost:8000/health"
    echo ""
    echo "常用命令:"
    echo "  检查服务: ./scripts/check-vllm.sh"
    echo "  查看日志: tail -f logs/vllm-service.log"
    echo "  重启服务: ./scripts/stop-vllm.sh && ./scripts/start-vllm.sh"
    echo "  停止服务: ./scripts/stop-vllm.sh"
    echo ""
    echo "详细日志: $MAIN_LOG"
    echo "================================================================"
}

# 捕获中断信号
trap 'echo "❌ 部署被中断"; exit 1' INT

# 参数处理
if [[ $# -eq 0 ]]; then
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  --full       执行完整部署（默认）"
    echo "  --check      仅检查系统要求"
    echo "  --docker     仅安装Docker"
    echo "  --modelscope 仅安装ModelScope"
    echo "  --model      仅下载模型"
    echo "  --vllm       仅设置vLLM"
    echo "  --start      仅启动vLLM服务"
    echo "  --verify     仅验证服务"
    echo "  --docker-only 仅安装Docker"
    echo "  --vllm-only  仅启动vLLM服务"
    echo ""
    read -p "按回车键开始完整部署，或按Ctrl+C取消: "
    main
else
    case "$1" in
        --full)
            main
            ;;
        --check)
            check_requirements
            ;;
        --docker)
            install_docker
            ;;
        --modelscope)
            install_modelscope
            ;;
        --model)
            download_model
            ;;
        --vllm)
            setup_vllm
            ;;
        --start)
            start_vllm_service
            ;;
        --verify)
            final_verification
            ;;
        --docker-only)
            install_docker
            ;;
        --vllm-only)
            start_vllm_service
            ;;
        *)
            echo "未知选项: $1"
            exit 1
            ;;
    esac
fi
