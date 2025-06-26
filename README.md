# 一体机AI服务部署项目

这个项目提供了一个完整的一体机AI服务部署方案，采用本地vLLM部署架构，包括Docker基础设施、ModelScope和Qwen3-32B模型的自动化部署。

## 架构特点

- **高性能**: vLLM直接在宿主机运行，无容器化开销
- **灵活配置**: 易于调整GPU使用和模型参数  
- **简化运维**: 直接进程管理，便于监控和调试
- **Docker基础**: Docker仅用于可选的监控和辅助服务

## 项目结构

```
/home/user/machine/
├── config/                 # 配置文件目录
│   ├──### 更新和升级

### 更新vLLM

```bash
source venv/bin/activate
pip install --upgrade vllm
```

### 更新其他依赖

```bash
source venv/bin/activate  
pip install --upgrade -r requirements.txt
```

### 更新Docker镜像（可选服务）

```bash
docker-compose -f docker/docker-compose.yml pull
docker-compose -f docker/docker-compose.yml up -d
```l    # vLLM服务配置
│   └── model-config.yml   # 模型配置
├── docker/                # Docker相关文件
│   └── docker-compose.yml # Docker Compose配置
├── docs/                  # 文档目录
│   ├── deployment-guide.md # 部署指南
│   └── api-usage-guide.md # API使用指南
├── scripts/               # 脚本目录
│   ├── deploy-all.sh      # 一键部署脚本
│   ├── install-docker.sh  # Docker安装脚本
│   ├── install-modelscope.sh # ModelScope安装脚本
│   ├── download-model.sh  # 模型下载脚本
│   ├── setup-vllm.sh      # vLLM设置脚本
│   ├── start-service.sh   # 服务启动脚本
│   ├── check-service.sh   # 服务检查脚本
│   ├── start-vllm.sh      # vLLM启动脚本
│   ├── stop-vllm.sh       # vLLM停止脚本
│   ├── check-vllm.sh      # vLLM检查脚本
│   └── activate-env.sh    # 环境激活脚本
├── models/                # 模型存储目录（自动创建）
├── logs/                  # 日志目录（自动创建）
├── venv/                  # Python虚拟环境（自动创建）
└── requirements.txt       # Python依赖列表
```

## 快速开始

### 一键部署

最简单的方式是使用一键部署脚本：

```bash
cd /home/user/machine
./scripts/deploy-all.sh
```

这个脚本会自动完成以下步骤：
1. 检查系统要求
2. 安装Docker（用于基础服务）
3. 安装ModelScope和Python环境
4. 下载Qwen3-32B模型
5. 设置vLLM（本地安装）
6. 启动vLLM服务（本地运行）

### 分步骤部署

如果需要分步骤部署或调试问题，可以运行单独的脚本：

```bash
# 1. 安装Docker（基础服务）
./scripts/install-docker.sh

# 2. 安装ModelScope和Python环境
./scripts/install-modelscope.sh

# 3. 下载模型（需要较长时间）
./scripts/download-model.sh

# 4. 设置vLLM（本地安装）
./scripts/setup-vllm.sh

# 5. 启动vLLM服务（本地运行）
./scripts/start-vllm.sh

# 6. 检查服务状态
./scripts/check-vllm.sh
```

## 系统要求

### 硬件要求

- **GPU**: 推荐NVIDIA GPU，显存≥80GB（用于Qwen3-32B）
- **内存**: 系统内存≥64GB
- **存储**: 至少200GB可用空间
- **CPU**: 多核处理器，推荐16核以上

### 软件要求

- **操作系统**: Ubuntu 20.04+ / CentOS 7+ / RHEL 8+
- **Python**: 3.8+
- **CUDA**: 11.8+ (如果使用GPU)

## 服务管理

### 启动服务

```bash
# 启动vLLM服务（本地）
./scripts/start-vllm.sh

# 或启动所有服务（包括可选的Docker服务）
./scripts/start-service.sh
```

### 检查服务状态

```bash
# 检查vLLM服务
./scripts/check-vllm.sh

# 全面检查（包括系统资源）
./scripts/check-service.sh
```

### 停止服务

```bash
# 停止vLLM服务
./scripts/stop-vllm.sh

# 停止Docker服务（如果有）
docker-compose -f docker/docker-compose.yml down
```

### 查看日志

```bash
# 查看vLLM服务日志
tail -f logs/vllm-service.log

# 查看部署日志
tail -f logs/deployment.log

# 查看Docker容器日志（如果使用）
docker-compose -f docker/docker-compose.yml logs -f
```

## API使用

服务启动后，可以通过以下地址访问：

- **API地址**: http://localhost:8000
- **健康检查**: http://localhost:8000/health
- **模型列表**: http://localhost:8000/v1/models
- **聊天API**: http://localhost:8000/v1/chat/completions

### 快速测试

```bash
# 健康检查
curl http://localhost:8000/health

# 发送聊天请求
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3-32B",
    "messages": [{"role": "user", "content": "你好"}],
    "max_tokens": 50
  }'
```

详细的API使用方法请参考 [API使用指南](docs/api-usage-guide.md)。

## 配置说明

### vLLM配置

主要配置文件: `config/vllm-config.yml`

```yaml
# 性能配置
performance:
  tensor_parallel_size: 4      # GPU并行数量
  gpu_memory_utilization: 0.8  # GPU内存使用率
  max_model_len: 4096         # 最大上下文长度
```

### 环境配置

- **Python虚拟环境**: `/home/user/machine/venv`
- **模型存储**: `/home/user/machine/models`
- **配置文件**: `/home/user/machine/config`
- **日志文件**: `/home/user/machine/logs`

### Docker配置

Docker Compose配置: `docker/docker-compose.yml`

仅包含可选的监控服务（Prometheus, Grafana）。

## 故障排除

### 常见问题

1. **Docker权限问题**
   ```bash
   # 将用户添加到docker组
   sudo usermod -aG docker $USER
   # 重新登录或运行
   newgrp docker
   ```

2. **GPU内存不足**
   - 降低 `gpu_memory_utilization` 参数
   - 减少 `tensor_parallel_size`
   - 考虑使用CPU推理

3. **模型下载失败**
   - 检查网络连接
   - 使用代理或镜像源
   - 手动重试下载

3. **服务启动缓慢**
   - 模型加载需要时间，请耐心等待
   - 检查GPU和内存资源
   - 查看详细日志：`tail -f logs/vllm-service.log`

4. **进程管理问题**
   ```bash
   # 查看vLLM进程
   ps aux | grep vllm
   
   # 强制停止进程
   pkill -f "vllm.entrypoints.openai.api_server"
   ```

### 日志查看

```bash
# 系统日志
journalctl -f

# vLLM服务日志
tail -f logs/vllm-service.log

# 所有日志文件
ls -la logs/

# 进程状态
ps aux | grep vllm
```

## 性能优化

### 本地部署优化

1. **直接GPU访问**：
   ```bash
   # 设置GPU环境变量
   export CUDA_VISIBLE_DEVICES=0,1,2,3
   ```

2. **内存优化**：
   ```bash
   # PyTorch内存优化
   export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128
   ```

3. **启动参数优化**：
   ```bash
   python -m vllm.entrypoints.openai.api_server \
       --model /home/user/machine/models/Qwen/Qwen3-32B \
       --tensor-parallel-size 4 \
       --gpu-memory-utilization 0.8 \
       --max-model-len 4096 \
       --disable-log-stats \
       --trust-remote-code
   ```

### 模型优化

1. 使用量化模型以节省显存
2. 调整上下文长度：
   ```yaml
   max_model_len: 2048  # 根据需要调整
   ```

## 监控和维护

### 监控脚本

定期运行检查脚本：
```bash
# 添加到crontab
echo "*/5 * * * * /home/user/machine/scripts/check-service.sh >> /home/user/machine/logs/monitor.log 2>&1" | crontab -
```

### 备份

重要文件备份：
```bash
# 备份配置
cp -r config/ backup/config-$(date +%Y%m%d)/

# 备份脚本
cp -r scripts/ backup/scripts-$(date +%Y%m%d)/
```

## 更新和升级

### 更新vLLM

```bash
source venv/bin/activate
pip install --upgrade vllm
```

### 更新Docker镜像

```bash
docker-compose -f docker/docker-compose.yml pull
docker-compose -f docker/docker-compose.yml up -d
```

## 安全注意事项

1. **网络安全**: 配置防火墙规则
2. **访问控制**: 限制API访问
3. **资源监控**: 定期检查资源使用
4. **日志轮转**: 配置日志轮转避免磁盘满

## 支持和贡献

### 文档

- [部署指南](docs/deployment-guide.md) - 详细的部署说明
- [API使用指南](docs/api-usage-guide.md) - API使用方法和示例

### 问题反馈

如遇到问题，请：
1. 检查日志文件
2. 运行诊断脚本
3. 查看常见问题解决方案

### 项目维护

定期执行：
- 系统更新
- 依赖包更新
- 配置优化
- 性能监控

## 许可证

本项目遵循相关开源协议，使用前请确保了解各组件的许可证要求。
