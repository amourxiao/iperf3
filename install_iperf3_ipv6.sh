#!/bin/bash

# install_iperf3_ipv6.sh
# 用于在 Debian 系统上安装 iperf3，并启动 IPv6 服务器，允许用户自定义端口

# 默认端口
DEFAULT_PORT=5022

# 函数：显示使用说明
show_help() {
    echo "Usage: bash install_iperf3_ipv6.sh [-p PORT]"
    echo
    echo "Options:"
    echo "  -p PORT    指定要使用的端口号 (默认: $DEFAULT_PORT)"
    echo "  -h         显示帮助信息"
}

# 函数：检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 函数：验证端口号
validate_port() {
    local port=$1
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "错误: 端口号必须是数字。"
        exit 1
    fi
    if (( port < 1 || port > 65535 )); then
        echo "错误: 端口号必须在1到65535之间。"
        exit 1
    fi
}

# 函数：检查端口是否被占用
check_port() {
    local port=$1
    if sudo lsof -i TCP6:"$port" -s TCP:LISTEN -t >/dev/null ; then
        echo "错误: 端口 $port 已被占用。请选择其他端口。"
        exit 1
    fi
}

# 解析命令行参数
PORT=$DEFAULT_PORT

while getopts ":p:h" opt; do
    case ${opt} in
        p )
            PORT=$OPTARG
            ;;
        h )
            show_help
            exit 0
            ;;
        \? )
            echo "无效的选项: -$OPTARG" >&2
            show_help
            exit 1
            ;;
        : )
            echo "选项 -$OPTARG 需要一个参数。" >&2
            show_help
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

# 验证端口号
validate_port "$PORT"

# 检查端口是否被占用
check_port "$PORT"

echo "使用端口号: $PORT"

# 更新包列表（如果需要，可以取消注释以下行）
# echo "更新包列表..."
# sudo apt update

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

# 获取本机的外网 IPv6 地址
echo "获取外网 IPv6 地址..."
EXTERNAL_IP=$(curl -s https://icanhazip.com)

# 检查是否成功获取到外网 IP
if [[ $? -ne 0 || -z "$EXTERNAL_IP" ]]; then
    echo "未能获取到外网 IPv6 地址。请检查网络连接或服务状态。"
    exit 1
fi

echo "外网 IPv6 地址为: $EXTERNAL_IP"

# 输出带有外网 IP 和自定义端口的客户端命令
echo "客户端命令如下："
echo "iperf3 -c $EXTERNAL_IP -p $PORT -t 30 -P 1 -R"

# 启动 iperf3 IPv6 服务器
echo "启动 iperf3 IPv6 服务器..."
# 使用 & 将服务器放到后台运行，避免阻塞脚本
iperf3 -s -6 -p "$PORT" &
# 获取服务器进程的 PID
IPERF3_PID=$!
echo "iperf3 IPv6 服务器已启动，进程 PID: $IPERF3_PID"

# 可选：保持脚本运行，直到用户手动停止
echo "按 [CTRL+C] 停止 iperf3 IPv6 服务器。"
wait "$IPERF3_PID"
