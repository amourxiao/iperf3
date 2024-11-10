#!/bin/bash

# 定义使用的端口和其他参数
PORT=5022
DURATION=30
PARALLEL=1

# 函数：检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查并安装 iperf3
if command_exists iperf3; then
    echo "iperf3 已经安装，跳过安装步骤。"
else
    echo "安装 iperf3..."
    sudo apt install -y iperf3
    if ! command_exists iperf3; then
        echo "iperf3 安装失败。请检查网络连接或包管理器状态。"
        exit 1
    fi
fi

# 检查并安装 curl
if command_exists curl; then
    echo "curl 已经安装，跳过安装步骤。"
else
    echo "安装 curl..."
    sudo apt install -y curl
    if ! command_exists curl; then
        echo "curl 安装失败。请检查网络连接或包管理器状态。"
        exit 1
    fi
fi

# 获取本机的外网 IP 地址
echo "获取外网 IP 地址..."
EXTERNAL_IP=$(curl -s 4.ipw.cn)

# 检查是否成功获取到外网 IP
if [[ $? -ne 0 || -z "$EXTERNAL_IP" ]]; then
    echo "未能获取到外网 IP 地址。请检查网络连接或 4.ipw.cn 服务状态。"
    exit 1
fi

echo "外网 IP 地址为: $EXTERNAL_IP"

# 输出带有外网 IP 的客户端命令
echo "客户端命令如下："
echo "iperf3 -c $EXTERNAL_IP -p $PORT -t $DURATION -P $PARALLEL -R"

# 启动 iperf3 服务器
echo "启动 iperf3 服务器..."
# 使用 & 将服务器放到后台运行，避免阻塞脚本
iperf3 -s -p $PORT &
# 获取服务器进程的 PID
IPERF3_PID=$!
echo "iperf3 服务器已启动，进程 PID: $IPERF3_PID"

# 可选：保持脚本运行，直到用户手动停止
echo "按 [CTRL+C] 停止 iperf3 服务器。"
wait $IPERF3_PID
