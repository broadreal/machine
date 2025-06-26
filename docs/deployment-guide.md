# 一体机软件部署方案

## 概述

本文档描述了在一体机上部署大语言模型服务的完整方案，包括以下组件：
- **Docker** - 基础容器化平台（用于其他服务）
- **ModelScope** - 模型下载和管理工具
- **vLLM** - 高性能大语言模型推理引擎（本地部署）
- **Qwen3-32B** - 通义千问3代32B参数模型

## 架构说明

本方案采用混合部署架构：
- **vLLM服务**：直接在宿主机运行，获得最佳性能
- **Docker**：作为基础设施，用于可选的监控和其他辅助服务
- **模型文件**：存储在宿主机，避免容器化的存储开销

## 系统要求

### 硬件要求
- **GPU**: 推荐使用NVIDIA GPU，显存≥80GB（用于Qwen3-32B）
- **内存**: 系统内存≥64GB
- **存储**: 至少200GB可用空间（模型文件约60GB）
- **CPU**: 多核处理器，推荐16核以上

### 软件要求
- **操作系统**: Ubuntu 20.04+ / CentOS 7+ / RHEL 8+
- **Python**: 3.8+
- **CUDA**: 11.8+ (如果使用GPU)
- **Docker**: 20.10+ (用于基础服务)

## 部署步骤

### 方案一：一键自动部署（推荐）

运行自动化部署脚本：
```bash
cd /home/user/machine
./scripts/deploy-all.sh
```

### 方案二：分步部署

#### 步骤1：安装Docker（基础服务）
```bash
./scripts/install-docker.sh
```

Docker主要用于：
- 可选的监控服务（Prometheus、Grafana）
- 其他辅助服务
- 开发和测试环境

#### 步骤2：安装ModelScope
```bash
./scripts/install-modelscope.sh
```

这将：
- 创建Python虚拟环境
- 安装ModelScope和相关依赖
- 配置模型下载环境

#### 步骤3：下载Qwen3-32B模型
```bash
./scripts/download-model.sh
```

模型将下载到：`/home/user/machine/models/Qwen/Qwen3-32B`

#### 步骤4：设置vLLM（本地安装）
```bash
./scripts/setup-vllm.sh
```

这将：
- 在虚拟环境中安装vLLM
- 创建vLLM配置文件
- 生成启动和管理脚本

#### 步骤5：启动vLLM服务
```bash
./scripts/start-vllm.sh
```

服务将直接在宿主机上运行，监听端口8000。

### 手动部署步骤（详细版）

如果自动化脚本失败，可以按照以下步骤手动部署：

#### 1. 安装Docker
```bash
# 更新系统包
sudo apt update

# 安装Docker依赖
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# 添加Docker官方GPG密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 添加Docker仓库
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 将当前用户添加到docker组
sudo usermod -aG docker $USER
```

#### 2. 创建Python虚拟环境
```bash
# 安装Python虚拟环境工具
sudo apt install -y python3-pip python3-venv python3-dev

# 创建虚拟环境
python3 -m venv /home/user/machine/venv

# 激活虚拟环境
source /home/user/machine/venv/bin/activate
```

#### 3. 安装ModelScope和依赖
```bash
# 激活虚拟环境
source /home/user/machine/venv/bin/activate

# 更新pip
pip install --upgrade pip

# 安装ModelScope
pip install modelscope[nlp] -i https://pypi.douban.com/simple/

# 安装PyTorch（GPU版本）
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# 安装其他依赖
pip install transformers accelerate tensorboard
```

#### 4. 下载模型
```bash
# 激活虚拟环境
source /home/user/machine/venv/bin/activate

# 创建模型目录
mkdir -p /home/user/machine/models

# 下载模型
python -c "
from modelscope import snapshot_download
model_dir = snapshot_download('Qwen/Qwen3-32B', cache_dir='/home/user/machine/models')
print(f'Model downloaded to: {model_dir}')
"
```

#### 5. 安装vLLM
```bash
# 激活虚拟环境
source /home/user/machine/venv/bin/activate

# 安装vLLM
pip install vllm
```

#### 6. 启动vLLM服务
```bash
# 激活虚拟环境
source /home/user/machine/venv/bin/activate

# 启动vLLM服务
python -m vllm.entrypoints.openai.api_server \
    --model /home/user/machine/models/Qwen/Qwen3-32B \
    --host 0.0.0.0 \
    --port 8000 \
    --tensor-parallel-size 4 \
    --gpu-memory-utilization 0.8 \
    --max-model-len 4096 \
    --trust-remote-code
```

## 服务管理

### vLLM服务管理

```bash
# 启动vLLM服务
./scripts/start-vllm.sh

# 检查vLLM状态
./scripts/check-vllm.sh

# 停止vLLM服务
./scripts/stop-vllm.sh
```

### Docker服务管理（可选监控服务）

```bash
# 启动监控服务
docker-compose -f docker/docker-compose.yml --profile monitoring up -d

# 停止监控服务
docker-compose -f docker/docker-compose.yml down
```

### 验证部署

检查服务状态：
```bash
# 全面检查
./scripts/check-service.sh

# 或单独检查vLLM
curl http://localhost:8000/health

# 测试API
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3-32B",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 50
  }'
```

## 配置说明

### vLLM配置
配置文件位于 `config/vllm-config.yml`，主要参数：
- `model`: 模型路径（本地路径）
- `host`: 服务监听地址
- `port`: 服务端口
- `tensor_parallel_size`: GPU并行数量
- `gpu_memory_utilization`: GPU内存使用率

### 环境配置
- **虚拟环境**：`/home/user/machine/venv`
- **模型存储**：`/home/user/machine/models`
- **配置文件**：`/home/user/machine/config`
- **日志文件**：`/home/user/machine/logs`

## 性能优化

### 本地部署优势
1. **直接硬件访问**：无容器化开销
2. **内存共享**：高效的GPU内存管理
3. **网络性能**：无需容器网络映射
4. **调试便利**：直接访问进程和日志

### 优化建议
```bash
# GPU优化
export CUDA_VISIBLE_DEVICES=0,1,2,3  # 指定使用的GPU

# 内存优化
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128

# 启动优化参数
python -m vllm.entrypoints.openai.api_server \
    --model /home/user/machine/models/Qwen/Qwen3-32B \
    --tensor-parallel-size 4 \
    --gpu-memory-utilization 0.8 \
    --max-model-len 4096 \
    --disable-log-stats \
    --trust-remote-code
```

## 故障排除

### 常见问题

1. **虚拟环境问题**
   ```bash
   # 重新创建虚拟环境
   rm -rf /home/user/machine/venv
   python3 -m venv /home/user/machine/venv
   source /home/user/machine/venv/bin/activate
   ```

2. **GPU内存不足**
   - 减少 `gpu_memory_utilization` 参数
   - 减少 `tensor_parallel_size`
   - 使用更小的 `max_model_len`

3. **模型加载失败**
   - 检查模型文件完整性
   - 验证路径正确性
   - 确认有足够磁盘空间

4. **端口占用**
   ```bash
   # 查找占用端口的进程
   lsof -i :8000
   
   # 杀死进程
   pkill -f "vllm.entrypoints.openai.api_server"
   ```

### 日志查看
```bash
# vLLM服务日志
tail -f /home/user/machine/logs/vllm-service.log

# 系统日志
journalctl -f

# 检查GPU使用情况
nvidia-smi
```

## 监控和维护

### 系统监控
```bash
# GPU使用情况
watch -n 1 nvidia-smi

# 系统资源
htop

# 磁盘使用
df -h
```

### 定期维护
```bash
# 更新依赖包
source /home/user/machine/venv/bin/activate
pip install --upgrade vllm transformers

# 清理日志
find /home/user/machine/logs -name "*.log" -mtime +7 -delete

# 检查模型文件
du -sh /home/user/machine/models/*
```

### 服务自启动（可选）
创建systemd服务：
```bash
sudo tee /etc/systemd/system/vllm-qwen.service > /dev/null <<EOF
[Unit]
Description=vLLM Qwen3-32B Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/user/machine
Environment=PATH=/home/user/machine/venv/bin:/usr/bin:/bin
ExecStart=/home/user/machine/venv/bin/python -m vllm.entrypoints.openai.api_server --model /home/user/machine/models/Qwen/Qwen3-32B --host 0.0.0.0 --port 8000 --tensor-parallel-size 4 --gpu-memory-utilization 0.8 --max-model-len 4096 --trust-remote-code
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 启用服务
sudo systemctl enable vllm-qwen.service
sudo systemctl start vllm-qwen.service
```

## 安全注意事项

1. **网络安全**
   - 配置防火墙规则
   - 使用反向代理（nginx/apache）
   - 启用HTTPS

2. **访问控制**
   - 限制API访问IP
   - 添加认证机制
   - 设置请求频率限制

3. **资源保护**
   - 监控GPU使用情况
   - 设置内存使用限制
   - 定期备份配置文件

## 性能基准

### 预期性能指标
- **延迟**：首个token ~100-200ms
- **吞吐量**：~20-50 tokens/s（取决于硬件）
- **并发**：支持多个并发请求
- **内存使用**：~60-80GB GPU显存

### 性能测试
```bash
# 简单性能测试
time curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3-32B",
    "messages": [{"role": "user", "content": "Count from 1 to 10"}],
    "max_tokens": 50
  }'
```

## 联系支持

如有问题，请查看：
- 项目文档：`docs/`
- 配置示例：`config/`
- 部署脚本：`scripts/`
- 日志文件：`logs/`
