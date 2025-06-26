#!/bin/bash

# ModelScope 安装脚本

set -e

echo "=== ModelScope 安装脚本 ==="
echo "开始安装ModelScope..."

# 检查Python版本
python_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
required_version="3.8"

if [ "$(printf '%s\n' "$required_version" "$python_version" | sort -V | head -n1)" != "$required_version" ]; then
    echo "❌ Python版本不满足要求。需要Python 3.8+，当前版本：$python_version"
    exit 1
fi

echo "✅ Python版本检查通过：$python_version"

# 安装pip和虚拟环境工具（如果没有的话）
echo "安装Python包管理工具..."
sudo apt update
sudo apt install -y python3-pip python3-venv python3-dev

# 创建项目根目录下的虚拟环境目录
ENV_DIR="/home/user/machine/venv"
echo "创建虚拟环境目录：$ENV_DIR"

if [ -d "$ENV_DIR" ]; then
    echo "虚拟环境已存在，删除旧环境..."
    rm -rf "$ENV_DIR"
fi

# 创建虚拟环境
echo "创建Python虚拟环境..."
python3 -m venv "$ENV_DIR"

# 激活虚拟环境
echo "激活虚拟环境..."
source "$ENV_DIR/bin/activate"

# 更新pip
echo "更新pip..."
pip install --upgrade pip

# 配置国内镜像源
echo "配置pip镜像源..."
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
pip config set install.trusted-host mirrors.aliyun.com

# 安装PyTorch (GPU版本) - 使用官方国内源
echo "安装PyTorch (GPU版本)..."
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# 安装ModelScope及相关依赖
echo "安装ModelScope..."
pip install modelscope[nlp] -i https://mirrors.aliyun.com/pypi/simple/

# 安装其他必要的依赖
echo "安装其他依赖..."
pip install transformers accelerate torch_npu -i https://mirrors.aliyun.com/pypi/simple/
pip install tensorboard numpy pandas requests tqdm -i https://mirrors.aliyun.com/pypi/simple/

# 验证安装
echo "验证ModelScope安装..."
python -c "
try:
    import modelscope
    print('✅ ModelScope安装成功！版本：', modelscope.__version__)
except ImportError as e:
    print('❌ ModelScope安装失败：', e)
    exit(1)
"

# 创建模型存储目录
MODEL_DIR="/home/user/machine/models"
echo "创建模型存储目录：$MODEL_DIR"
mkdir -p "$MODEL_DIR"

# 创建环境激活脚本
ACTIVATE_SCRIPT="/home/user/machine/scripts/activate-env.sh"
echo "创建环境激活脚本：$ACTIVATE_SCRIPT"
cat > "$ACTIVATE_SCRIPT" << 'EOF'
#!/bin/bash
# 激活ModelScope虚拟环境
source /home/user/machine/venv/bin/activate
echo "✅ ModelScope虚拟环境已激活"
echo "Python路径: $(which python)"
echo "当前工作目录: $(pwd)"
EOF

chmod +x "$ACTIVATE_SCRIPT"

# 创建requirements.txt文件
REQUIREMENTS_FILE="/home/user/machine/requirements.txt"
echo "创建requirements.txt文件..."
cat > "$REQUIREMENTS_FILE" << 'EOF'
modelscope[nlp]
torch>=2.0.0
torchvision
torchaudio
transformers>=4.30.0
accelerate
tensorboard
vllm
fastapi
uvicorn
numpy
pandas
requests
tqdm
EOF

echo ""
echo "=== 安装完成 ==="
echo "ModelScope已成功安装在虚拟环境中"
echo ""
echo "使用方法："
echo "1. 激活环境：source /home/user/machine/venv/bin/activate"
echo "2. 或运行：./scripts/activate-env.sh"
echo "3. 模型存储目录：$MODEL_DIR"
echo ""
echo "验证安装："
echo "  source /home/user/machine/venv/bin/activate"
echo "  python -c 'import modelscope; print(modelscope.__version__)'"
echo ""
