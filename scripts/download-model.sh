#!/bin/bash

# 模型下载脚本 - 支持多种模型

set -e

# 参数解析
MODEL_PARAM="${1:-Qwen3-32B}"  # 默认下载Qwen3-32B

# 模型映射表
declare -A MODEL_MAP=(
    ["Qwen3-32B"]="Qwen/Qwen3-32B"
    ["Qwen2-32B"]="Qwen/Qwen2-32B-Instruct"
    ["Qwen2-7B"]="Qwen/Qwen2-7B-Instruct"
    ["Qwen2-1.5B"]="Qwen/Qwen2-1.5B-Instruct"
)

# 获取实际模型名称
if [[ -n "${MODEL_MAP[$MODEL_PARAM]}" ]]; then
    MODEL_NAME="${MODEL_MAP[$MODEL_PARAM]}"
    DISPLAY_NAME="$MODEL_PARAM"
else
    MODEL_NAME="$MODEL_PARAM"  # 直接使用用户输入
    DISPLAY_NAME="$MODEL_PARAM"
fi

echo "=== 模型下载脚本 ==="
echo "下载模型：$DISPLAY_NAME ($MODEL_NAME)"

# 配置变量
ENV_DIR="/home/user/machine/venv"
MODEL_DIR="/home/user/machine/models"
LOG_FILE="/home/user/machine/logs/model-download.log"

# 创建日志目录
mkdir -p "$(dirname "$LOG_FILE")"

# 检查依赖
echo "检查环境依赖..."

# 检查Python环境
if ! command -v python &> /dev/null; then
    echo "❌ Python 未安装或不在PATH中"
    exit 1
fi

# 检查ModelScope和相关依赖
echo "检查下载工具..."
DOWNLOAD_DEPS_CHECK=$(python -c "
import sys
import subprocess

def check_and_install_dependencies():
    try:
        # 检查ModelScope
        try:
            import modelscope
            print('OK: ModelScope available')
        except ImportError:
            print('INFO: Installing ModelScope...')
            subprocess.run([sys.executable, '-m', 'pip', 'install', 'modelscope', 
                          '-i', 'https://mirrors.aliyun.com/pypi/simple/'], 
                          check=True, capture_output=True)
            import modelscope
            print('OK: ModelScope installed successfully')
        
        # 检查其他依赖
        try:
            import requests
            print('OK: requests available')
        except ImportError:
            print('INFO: Installing requests...')
            subprocess.run([sys.executable, '-m', 'pip', 'install', 'requests'], 
                          check=True, capture_output=True)
            print('OK: requests installed')
            
        try:
            import tqdm
            print('OK: tqdm available')
        except ImportError:
            print('INFO: Installing tqdm...')
            subprocess.run([sys.executable, '-m', 'pip', 'install', 'tqdm'], 
                          check=True, capture_output=True)
            print('OK: tqdm installed')
        
        return True
        
    except Exception as e:
        print(f'ERROR: {e}')
        return False

if not check_and_install_dependencies():
    sys.exit(1)
" 2>&1)

if [[ $DOWNLOAD_DEPS_CHECK == *ERROR* ]]; then
    echo "❌ 下载工具检查失败:"
    echo "$DOWNLOAD_DEPS_CHECK"
    exit 1
else
    echo "✅ 下载工具检查通过"
    echo "$DOWNLOAD_DEPS_CHECK" | grep "OK:"
fi

# 检查虚拟环境（可选）
if [ -d "$ENV_DIR" ]; then
    echo "✅ 发现虚拟环境：$ENV_DIR"
    source "$ENV_DIR/bin/activate"
else
    echo "⚠️  未发现虚拟环境，使用系统Python"
fi

# 检查模型存储目录
mkdir -p "$MODEL_DIR"

# 检查目标模型是否已存在
TARGET_MODEL_PATH="$MODEL_DIR/$(basename "$MODEL_NAME")"
if [ -d "$TARGET_MODEL_PATH" ]; then
    echo "⚠️  模型已存在：$TARGET_MODEL_PATH"
    echo "是否要重新下载？(y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "取消下载，使用现有模型"
        exit 0
    fi
    echo "正在清理现有模型..."
    rm -rf "$TARGET_MODEL_PATH"
fi

echo "开始下载 $DISPLAY_NAME 模型..."
echo "模型存储路径：$MODEL_DIR"
echo "日志文件：$LOG_FILE"

# 检查可用空间（预估模型大小）
available_space=$(df "$MODEL_DIR" | tail -1 | awk '{print $4}')

# 根据模型设置所需空间
case "$DISPLAY_NAME" in
    "Qwen3-32B"|"Qwen2-32B")
        required_space=$((60 * 1024 * 1024)) # 60GB in KB
        echo "预计需要空间：60GB"
        ;;
    "Qwen2-7B")
        required_space=$((15 * 1024 * 1024)) # 15GB in KB
        echo "预计需要空间：15GB"
        ;;
    "Qwen2-1.5B")
        required_space=$((5 * 1024 * 1024)) # 5GB in KB
        echo "预计需要空间：5GB"
        ;;
    *)
        required_space=$((30 * 1024 * 1024)) # 默认30GB in KB
        echo "预计需要空间：30GB（估算）"
        ;;
esac

if [ "$available_space" -lt "$required_space" ]; then
    echo "❌ 磁盘空间不足！"
    echo "需要空间：$(($required_space/1024/1024))GB"
    echo "可用空间：$(($available_space/1024/1024))GB"
    exit 1
fi

echo "✅ 磁盘空间检查通过"

# 创建下载脚本 - 使用ModelScope下载
DOWNLOAD_SCRIPT="/tmp/download_qwen.py"
cat > "$DOWNLOAD_SCRIPT" << EOF
import os
import sys
import time
from pathlib import Path

# 设置环境变量
os.environ['MODELSCOPE_CACHE'] = '$MODEL_DIR/.cache/modelscope'
os.environ['HF_ENDPOINT'] = 'https://hf-mirror.com'

try:
    from modelscope import snapshot_download
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
    
    def download_with_retry(model_id, cache_dir, max_retries=3):
        """带重试的模型下载"""
        for attempt in range(max_retries):
            try:
                logger.info(f"第 {attempt + 1} 次尝试下载模型: {model_id}")
                
                model_dir = snapshot_download(
                    model_id=model_id,
                    cache_dir=cache_dir,
                    revision='master',
                    local_files_only=False
                )
                
                logger.info(f"✅ 模型下载成功！")
                logger.info(f"模型路径: {model_dir}")
                return model_dir
                
            except Exception as e:
                logger.error(f"第 {attempt + 1} 次下载失败: {str(e)}")
                if attempt < max_retries - 1:
                    wait_time = 30 * (attempt + 1)  # 递增等待时间
                    logger.info(f"等待 {wait_time} 秒后重试...")
                    time.sleep(wait_time)
                else:
                    logger.error("所有下载尝试都失败了")
                    raise e
    
    # 开始下载
    logger.info("开始下载模型: $MODEL_NAME")
    logger.info("目标目录: $MODEL_DIR")
    
    model_dir = download_with_retry('$MODEL_NAME', '$MODEL_DIR')
    
    # 验证下载结果
    if os.path.exists(model_dir):
        files = list(Path(model_dir).rglob('*'))
        logger.info(f"下载的文件总数: {len(files)}")
        
        # 检查关键文件
        key_files = ['config.json', 'tokenizer.json', 'pytorch_model.bin', 'model.safetensors']
        found_files = []
        for key_file in key_files:
            if any(f.name == key_file for f in files):
                found_files.append(key_file)
        
        logger.info(f"找到关键文件: {', '.join(found_files)}")
        
        # 列出主要文件
        important_files = [f for f in files if f.suffix in ['.bin', '.safetensors', '.json', '.txt']]
        logger.info("主要文件:")
        for file in important_files:
            if file.is_file():
                size_mb = file.stat().st_size / (1024 * 1024)
                logger.info(f"  - {file.name}: {size_mb:.2f} MB")
        
        # 检查模型完整性
        has_config = any(f.name == 'config.json' for f in files)
        has_model = any(f.suffix in ['.bin', '.safetensors'] for f in files)
        
        if not has_config:
            logger.warning("⚠️  缺少config.json文件")
        if not has_model:
            logger.warning("⚠️  缺少模型权重文件")
            
        if has_config and has_model:
            logger.info("✅ 模型文件完整性检查通过")
    
    print(f"MODEL_PATH={model_dir}")
    
except ImportError as e:
    print(f"❌ 导入错误: {e}")
    print("请确保已安装 modelscope 包")
    sys.exit(1)
except Exception as e:
    print(f"❌ 下载失败: {e}")
    sys.exit(1)
EOF

# 执行下载
echo "正在下载模型，这可能需要较长时间..."
python "$DOWNLOAD_SCRIPT" 2>&1 | tee -a "$LOG_FILE"

if [ $? -eq 0 ]; then
    echo ""
    echo "=== 下载完成 ==="
    echo "✅ $DISPLAY_NAME 模型下载成功！"
    echo "模型位置：$MODEL_DIR"
    echo "日志文件：$LOG_FILE"
    
    # 显示模型信息
    echo ""
    echo "模型信息："
    du -sh "$MODEL_DIR"/* 2>/dev/null || echo "正在计算模型大小..."
    
    # 找到实际的模型路径
    ACTUAL_MODEL_PATH=$(find "$MODEL_DIR" -name "$(basename "$MODEL_NAME")" -type d | head -1)
    if [ -n "$ACTUAL_MODEL_PATH" ]; then
        echo "实际模型路径：$ACTUAL_MODEL_PATH"
        
        # 创建符号链接到预期位置（如果需要）
        EXPECTED_PATH="/home/user/machine/models/$(basename "$MODEL_NAME")"
        if [ "$ACTUAL_MODEL_PATH" != "$EXPECTED_PATH" ] && [ ! -L "$EXPECTED_PATH" ]; then
            echo "创建符号链接：$EXPECTED_PATH -> $ACTUAL_MODEL_PATH"
            ln -sf "$ACTUAL_MODEL_PATH" "$EXPECTED_PATH"
        fi
    fi
    
    # 创建或更新模型配置文件
    CONFIG_FILE="/home/user/machine/config/model-config.yml"
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    cat > "$CONFIG_FILE" << EOF
# $DISPLAY_NAME 模型配置
model:
  name: "$DISPLAY_NAME"
  path: "${ACTUAL_MODEL_PATH:-$MODEL_DIR/$(basename "$MODEL_NAME")}"
  type: "chat"
  full_name: "$MODEL_NAME"
  
  # vLLM配置
  vllm:
    model: "${ACTUAL_MODEL_PATH:-$MODEL_DIR/$(basename "$MODEL_NAME")}"
    tensor_parallel_size: 4  # 根据GPU数量调整
    gpu_memory_utilization: 0.8
    max_model_len: 4096
    
  # 服务配置
  service:
    host: "0.0.0.0"
    port: 8000
    workers: 1
EOF

    echo "模型配置文件已更新：$CONFIG_FILE"
    
else
    echo "❌ 模型下载失败，请查看日志：$LOG_FILE"
    exit 1
fi

# 清理临时文件
rm -f "$DOWNLOAD_SCRIPT"

echo ""
echo "使用说明："
echo "  bash $0 [模型名称]"
echo ""
echo "支持的模型："
echo "  - Qwen3-32B    (默认)"
echo "  - Qwen2-32B"
echo "  - Qwen2-7B"
echo "  - Qwen2-1.5B"
echo "  - 或直接使用 ModelScope 模型路径"
echo ""
echo "下一步："
echo "1. 检查模型：ls -la $MODEL_DIR"
echo "2. 运行 ./scripts/start-vllm.sh 启动服务"
echo ""
