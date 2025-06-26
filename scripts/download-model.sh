#!/bin/bash

# Qwen3-32B 模型下载脚本

set -e

echo "=== Qwen3-32B 模型下载脚本 ==="

# 配置变量
ENV_DIR="/home/user/machine/venv"
MODEL_DIR="/home/user/machine/models"
MODEL_NAME="Qwen/Qwen3-32B"
LOG_FILE="/home/user/machine/logs/model-download.log"

# 创建日志目录
mkdir -p "$(dirname "$LOG_FILE")"

# 检查虚拟环境
if [ ! -d "$ENV_DIR" ]; then
    echo "❌ 虚拟环境不存在，请先运行 install-modelscope.sh"
    exit 1
fi

# 检查模型存储目录
mkdir -p "$MODEL_DIR"

echo "开始下载 $MODEL_NAME 模型..."
echo "模型存储路径：$MODEL_DIR"
echo "日志文件：$LOG_FILE"

# 激活虚拟环境
source "$ENV_DIR/bin/activate"

# 检查可用空间（模型大约60GB）
available_space=$(df "$MODEL_DIR" | tail -1 | awk '{print $4}')
required_space=$((60 * 1024 * 1024)) # 60GB in KB

if [ "$available_space" -lt "$required_space" ]; then
    echo "❌ 磁盘空间不足！"
    echo "需要空间：60GB"
    echo "可用空间：$(($available_space/1024/1024))GB"
    exit 1
fi

echo "✅ 磁盘空间检查通过"

# 创建下载脚本
DOWNLOAD_SCRIPT="/tmp/download_qwen.py"
cat > "$DOWNLOAD_SCRIPT" << EOF
import os
import sys
from modelscope import snapshot_download
from tqdm import tqdm
import logging

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('$LOG_FILE'),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

def download_model():
    try:
        logger.info("开始下载模型: $MODEL_NAME")
        logger.info("目标目录: $MODEL_DIR")
        
        # 下载模型
        model_dir = snapshot_download(
            model_id='$MODEL_NAME',
            cache_dir='$MODEL_DIR',
            revision='master'
        )
        
        logger.info(f"✅ 模型下载成功！")
        logger.info(f"模型路径: {model_dir}")
        
        # 检查下载的文件
        if os.path.exists(model_dir):
            files = os.listdir(model_dir)
            logger.info(f"下载的文件数量: {len(files)}")
            
            # 列出主要文件
            important_files = [f for f in files if f.endswith(('.bin', '.safetensors', '.json', '.txt'))]
            logger.info("主要文件:")
            for file in important_files:
                file_path = os.path.join(model_dir, file)
                if os.path.exists(file_path):
                    size_mb = os.path.getsize(file_path) / (1024 * 1024)
                    logger.info(f"  - {file}: {size_mb:.2f} MB")
        
        return model_dir
        
    except Exception as e:
        logger.error(f"❌ 模型下载失败: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    model_path = download_model()
    print(f"MODEL_PATH={model_path}")
EOF

# 执行下载
echo "正在下载模型，这可能需要较长时间..."
python "$DOWNLOAD_SCRIPT" 2>&1 | tee -a "$LOG_FILE"

# 检查下载结果
if [ $? -eq 0 ]; then
    echo ""
    echo "=== 下载完成 ==="
    echo "✅ Qwen3-32B 模型下载成功！"
    echo "模型位置：$MODEL_DIR"
    echo "日志文件：$LOG_FILE"
    
    # 显示模型信息
    echo ""
    echo "模型信息："
    du -sh "$MODEL_DIR"/* 2>/dev/null || echo "正在计算模型大小..."
    
    # 创建模型配置文件
    CONFIG_FILE="/home/user/machine/config/model-config.yml"
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    cat > "$CONFIG_FILE" << EOF
# Qwen3-32B 模型配置
model:
  name: "Qwen3-32B"
  path: "$MODEL_DIR"
  type: "chat"
  parameters: "32B"
  
  # vLLM配置
  vllm:
    model: "$MODEL_DIR/Qwen/Qwen3-32B"
    tensor_parallel_size: 4  # 根据GPU数量调整
    gpu_memory_utilization: 0.8
    max_model_len: 4096
    
  # 服务配置
  service:
    host: "0.0.0.0"
    port: 8000
    workers: 1
EOF

    echo "模型配置文件已创建：$CONFIG_FILE"
    
else
    echo "❌ 模型下载失败，请查看日志：$LOG_FILE"
    exit 1
fi

# 清理临时文件
rm -f "$DOWNLOAD_SCRIPT"

echo ""
echo "下一步："
echo "1. 运行 ./scripts/setup-vllm.sh 安装vLLM"
echo "2. 运行 ./scripts/start-service.sh 启动服务"
echo ""
