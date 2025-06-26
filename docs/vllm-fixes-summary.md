# vLLM 环境问题修复总结

## 遇到的问题

### 1. torch-npu 与 torch 版本冲突
**问题描述**: torch-npu 2.2.0 与 torch 2.7.0 共存导致 vLLM 和 transformers 无法正常导入
**错误信息**: `ImportError` 和依赖冲突
**解决方案**: 卸载 torch-npu
```bash
pip uninstall torch-npu -y
```

### 2. 模型文件缺失
**问题描述**: start-vllm.sh 依赖的模型路径 `/home/user/machine/models/Qwen/Qwen3-32B` 不存在
**解决方案**: 先下载模型再启动服务

### 3. 脚本错误处理不完善
**问题描述**: 脚本缺乏对依赖冲突和模型缺失的检测
**解决方案**: 增强所有脚本的错误检测和处理能力

## 脚本改进总结

### 1. 增强的检查脚本 (check-vllm.sh)
- ✅ 添加了综合的依赖冲突检测
- ✅ 增强了模型路径和文件完整性检查
- ✅ 改进了错误信息和解决建议
- ✅ 添加了运行时模型路径验证

### 2. 增强的启动脚本 (start-vllm.sh)
- ✅ 添加了启动前的完整依赖检查
- ✅ 增加了自动依赖修复选项
- ✅ 改进了模型验证和交互式选择
- ✅ 增强了模型文件完整性检查

### 3. 增强的下载脚本 (download-model.sh)
- ✅ 改进了依赖安装和检查
- ✅ 增加了更多的错误处理

### 4. 新增的环境设置脚本 (setup-vllm.sh)
- ✅ 综合环境检查和问题修复
- ✅ 自动检测并修复 torch-npu 冲突
- ✅ 自动安装和验证 vLLM
- ✅ 交互式模型下载选项
- ✅ 生成标准化配置文件

## 修复的具体问题

### 依赖冲突检测
```python
# 检查torch-npu是否存在
result = subprocess.run(['pip', 'list'], capture_output=True, text=True)
pip_list = result.stdout

has_torch_npu = 'torch-npu' in pip_list
if has_torch_npu:
    print('ERROR: torch-npu detected, this may conflict with vLLM')
    return False
```

### 模型文件验证
```bash
# 验证模型文件完整性
if [ ! -f "$MODEL_PATH/config.json" ]; then
    echo "❌ 缺少配置文件：config.json"
    model_valid=false
fi

if [ ! -f "$MODEL_PATH/pytorch_model.bin" ] && [ ! -f "$MODEL_PATH/model.safetensors" ]; then
    echo "❌ 缺少模型权重文件"
    model_valid=false
fi
```

### 自动修复功能
```bash
echo "自动修复选项:"
echo "  1. 自动卸载torch-npu并重新安装vLLM? (y/n)"
read -r auto_fix
if [[ "$auto_fix" =~ ^[Yy]$ ]]; then
    echo "正在修复依赖问题..."
    pip uninstall torch-npu -y 2>/dev/null || true
    pip install vllm -i https://mirrors.aliyun.com/pypi/simple/
fi
```

## 使用流程

### 推荐的使用顺序
1. **环境设置**: `./scripts/setup-vllm.sh` - 一键检查和修复所有问题
2. **模型下载**: `./scripts/download-model.sh Qwen3-32B` - 如果模型不存在
3. **启动服务**: `./scripts/start-vllm.sh` - 启动 vLLM 服务
4. **状态检查**: `./scripts/check-vllm.sh` - 验证服务状态

### 单独使用
- 只检查环境: `./scripts/check-vllm.sh`
- 只启动服务: `./scripts/start-vllm.sh`
- 只下载模型: `./scripts/download-model.sh [model_name]`

## 日志和调试

### 日志文件位置
- 环境设置日志: `/home/user/machine/logs/vllm-setup.log`
- 服务运行日志: `/home/user/machine/logs/vllm-service.log`
- 模型下载日志: `/home/user/machine/logs/model-download.log`

### 调试命令
```bash
# 检查 vLLM 导入
python -c "import vllm; print(vllm.__version__)"

# 检查依赖冲突
pip list | grep torch

# 查看服务日志
tail -f /home/user/machine/logs/vllm-service.log

# 检查端口占用
lsof -i :8000
```

## 预防措施

### 避免再次出现问题
1. **定期检查**: 使用 `check-vllm.sh` 定期检查环境状态
2. **统一环境**: 建议使用虚拟环境隔离依赖
3. **版本锁定**: 在 requirements.txt 中锁定关键包版本
4. **监控日志**: 定期查看服务日志排查潜在问题

### 环境维护
```bash
# 定期清理缓存
pip cache purge

# 检查包冲突
pip check

# 更新关键包
pip install vllm --upgrade
```

## 总结

通过这些改进，现在的脚本具有：
- ✅ 自动问题检测和修复能力
- ✅ 更好的错误处理和用户提示
- ✅ 交互式操作选项
- ✅ 完整的日志记录
- ✅ 预防性检查机制

这确保了之前遇到的torch-npu冲突、模型缺失等问题不会再次发生，同时提供了更好的用户体验和故障排除能力。
