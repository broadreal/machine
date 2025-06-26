#!/bin/bash

# 环境安装统一脚本
# 用法: ./install-env.sh [modelscope|china|docker|all|help]

set -e

# 配置变量
VENV_DIR="/home/user/machine/venv"
LOG_DIR="/home/user/machine/logs"
LOG_FILE="$LOG_DIR/install-env.log"

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
    echo "环境安装统一脚本"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  modelscope  - 安装ModelScope和Python环境"
    echo "  china       - 配置中国大陆网络优化"
    echo "  docker      - 安装Docker环境"
    echo "  all         - 安装所有环境"
    echo "  help        - 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 all          # 安装所有环境（推荐）"
    echo "  $0 modelscope   # 只安装ModelScope环境"
    echo "  $0 china        # 只配置中国网络优化"
    echo ""
}

# 检查系统
check_system() {
    log "${BLUE}=== 系统检查 ===${NC}"
    
    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_info "操作系统: $NAME $VERSION"
    else
        log_warn "无法识别操作系统"
    fi
    
    # 检查Python
    if command -v python3 &> /dev/null; then
        local python_version=$(python3 --version 2>&1)
        log_info "$python_version"
    else
        log_error "Python3 未安装"
        return 1
    fi
    
    # 检查pip
    if command -v pip3 &> /dev/null; then
        local pip_version=$(pip3 --version 2>&1)
        log_info "pip: $pip_version"
    else
        log_error "pip3 未安装"
        return 1
    fi
    
    # 检查网络
    if curl -s --max-time 5 http://www.baidu.com > /dev/null; then
        log_info "网络连接正常"
    else
        log_warn "网络连接可能存在问题"
    fi
    
    return 0
}

# 安装ModelScope环境
install_modelscope() {
    log "${BLUE}=== 安装ModelScope环境 ===${NC}"
    
    # 检查虚拟环境
    if [ -d "$VENV_DIR" ]; then
        log_warn "虚拟环境已存在: $VENV_DIR"
        echo "是否删除重新创建？(y/N): "
        read -r recreate
        if [[ "$recreate" =~ ^[Yy]$ ]]; then
            rm -rf "$VENV_DIR"
            log_info "已删除现有虚拟环境"
        else
            log_info "使用现有虚拟环境"
        fi
    fi
    
    # 创建虚拟环境
    if [ ! -d "$VENV_DIR" ]; then
        log "创建Python虚拟环境..."
        python3 -m venv "$VENV_DIR" 2>&1 | tee -a "$LOG_FILE"
        log_info "虚拟环境创建完成"
    fi
    
    # 激活虚拟环境
    source "$VENV_DIR/bin/activate"
    
    # 升级pip
    log "升级pip..."
    pip install --upgrade pip -i https://mirrors.aliyun.com/pypi/simple/ 2>&1 | tee -a "$LOG_FILE"
    
    # 安装基础依赖
    log "安装基础依赖..."
    pip install wheel setuptools -i https://mirrors.aliyun.com/pypi/simple/ 2>&1 | tee -a "$LOG_FILE"
    
    # 安装ModelScope
    log "安装ModelScope..."
    pip install modelscope -i https://mirrors.aliyun.com/pypi/simple/ 2>&1 | tee -a "$LOG_FILE"
    
    # 安装其他工具
    log "安装其他工具..."
    pip install requests tqdm -i https://mirrors.aliyun.com/pypi/simple/ 2>&1 | tee -a "$LOG_FILE"
    
    # 验证安装
    log "验证安装..."
    python -c "
import modelscope
import requests
import tqdm
print('✅ ModelScope环境安装成功')
print(f'ModelScope版本: {modelscope.__version__}')
" 2>&1 | tee -a "$LOG_FILE"
    
    log_info "ModelScope环境安装完成"
}

# 配置中国网络优化
configure_china() {
    log "${BLUE}=== 配置中国网络优化 ===${NC}"
    
    # pip镜像配置
    log "配置pip镜像..."
    mkdir -p ~/.pip
    cat > ~/.pip/pip.conf << 'EOF'
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
trusted-host = mirrors.aliyun.com
timeout = 120

[install]
trusted-host = mirrors.aliyun.com
EOF
    log_info "pip镜像配置完成"
    
    # HuggingFace镜像
    log "配置HuggingFace镜像..."
    echo 'export HF_ENDPOINT=https://hf-mirror.com' >> ~/.bashrc
    export HF_ENDPOINT=https://hf-mirror.com
    log_info "HuggingFace镜像配置完成"
    
    # ModelScope缓存目录
    log "配置ModelScope缓存..."
    echo 'export MODELSCOPE_CACHE=/home/user/machine/models/.cache/modelscope' >> ~/.bashrc
    mkdir -p /home/user/machine/models/.cache/modelscope
    log_info "ModelScope缓存配置完成"
    
    # Git配置
    log "配置Git代理..."
    if command -v git &> /dev/null; then
        # 可以根据需要配置Git代理
        log_info "Git已安装"
    else
        log_warn "Git未安装，跳过Git配置"
    fi
    
    # DNS优化
    log "配置DNS优化..."
    echo "nameserver 223.5.5.5" | sudo tee /etc/resolv.conf.backup > /dev/null || log_warn "DNS配置需要root权限"
    
    log_info "中国网络优化配置完成"
}

# 安装Docker
install_docker() {
    log "${BLUE}=== 安装Docker ===${NC}"
    
    # 检查是否已安装
    if command -v docker &> /dev/null; then
        log_warn "Docker已安装"
        docker --version | tee -a "$LOG_FILE"
        return 0
    fi
    
    # 检查系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                log "在Ubuntu/Debian系统上安装Docker..."
                
                # 更新包索引
                sudo apt-get update 2>&1 | tee -a "$LOG_FILE"
                
                # 安装依赖
                sudo apt-get install -y \
                    apt-transport-https \
                    ca-certificates \
                    curl \
                    gnupg \
                    lsb-release 2>&1 | tee -a "$LOG_FILE"
                
                # 添加Docker官方GPG密钥
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                
                # 设置稳定版仓库
                echo \
                  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
                  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                
                # 安装Docker
                sudo apt-get update 2>&1 | tee -a "$LOG_FILE"
                sudo apt-get install -y docker-ce docker-ce-cli containerd.io 2>&1 | tee -a "$LOG_FILE"
                ;;
            centos|rhel|fedora)
                log "在CentOS/RHEL/Fedora系统上安装Docker..."
                
                # 安装依赖
                sudo yum install -y yum-utils 2>&1 | tee -a "$LOG_FILE"
                
                # 添加Docker仓库
                sudo yum-config-manager \
                    --add-repo \
                    https://download.docker.com/linux/centos/docker-ce.repo 2>&1 | tee -a "$LOG_FILE"
                
                # 安装Docker
                sudo yum install -y docker-ce docker-ce-cli containerd.io 2>&1 | tee -a "$LOG_FILE"
                ;;
            *)
                log_error "不支持的操作系统: $ID"
                return 1
                ;;
        esac
        
        # 启动Docker
        sudo systemctl start docker 2>&1 | tee -a "$LOG_FILE"
        sudo systemctl enable docker 2>&1 | tee -a "$LOG_FILE"
        
        # 添加用户到docker组
        sudo usermod -aG docker $USER 2>&1 | tee -a "$LOG_FILE"
        
        # 验证安装
        if sudo docker run hello-world 2>&1 | tee -a "$LOG_FILE"; then
            log_info "Docker安装成功"
        else
            log_error "Docker安装验证失败"
            return 1
        fi
        
    else
        log_error "无法识别操作系统，跳过Docker安装"
        return 1
    fi
}

# 安装所有环境
install_all() {
    log "${BLUE}=== 安装所有环境 ===${NC}"
    
    # 系统检查
    if ! check_system; then
        log_error "系统检查失败"
        exit 1
    fi
    
    # 中国网络优化
    configure_china
    
    # ModelScope环境
    install_modelscope
    
    # Docker环境（可选）
    echo "是否安装Docker？(y/N): "
    read -r install_docker_choice
    if [[ "$install_docker_choice" =~ ^[Yy]$ ]]; then
        install_docker
    else
        log_info "跳过Docker安装"
    fi
    
    log_info "所有环境安装完成！"
    echo ""
    echo "接下来可以："
    echo "  1. 下载模型: ./download-model.sh Qwen3-32B"
    echo "  2. 设置vLLM: ./vllm.sh setup"
    echo "  3. 启动服务: ./vllm.sh start"
    echo ""
    echo "注意：如果安装了Docker，请重新登录或运行 'newgrp docker' 来应用组权限"
}

# 主函数
main() {
    local command=${1:-help}
    
    case "$command" in
        modelscope)
            check_system && install_modelscope
            ;;
        china)
            configure_china
            ;;
        docker)
            install_docker
            ;;
        all)
            install_all
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
