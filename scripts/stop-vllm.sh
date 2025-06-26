#!/bin/bash

# vLLM 服务停止脚本

echo "=== 停止vLLM服务 ==="

# 查找vLLM进程
PIDS=$(pgrep -f "vllm.entrypoints.openai.api_server" || true)

if [ -z "$PIDS" ]; then
    echo "没有发现运行中的vLLM服务"
    exit 0
fi

echo "发现vLLM进程：$PIDS"

# 优雅停止
echo "正在停止vLLM服务..."
kill $PIDS

# 等待进程结束
sleep 5

# 检查是否还在运行
REMAINING_PIDS=$(pgrep -f "vllm.entrypoints.openai.api_server" || true)
if [ -n "$REMAINING_PIDS" ]; then
    echo "强制停止vLLM服务..."
    kill -9 $REMAINING_PIDS
fi

echo "✅ vLLM服务已停止"
