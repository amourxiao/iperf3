#!/bin/bash

# install_iperf3_1.sh
# 用于在 Debian 系统上安装 iperf3，并启动服务器，允许用户自定义端口

# 默认端口
DEFAULT_PORT=5022
PACKAGE_PORT=5201
IP_LOOKUP_URL="https://icanhazip.com"

# 函数：显示使用说明
show_help() {
    echo "Usage: bash install_iperf3_1.sh [-p PORT]"
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
    if ! [[ "$port" =~ ^0*([1-9][0-9]{0,4})$ ]] || (( BASH_REMATCH[1] > 65535 )); then
        echo "错误: 端口号必须在1到65535之间。"
        exit 1
    fi
    PORT=${BASH_REMATCH[1]}
}

# 函数：检查端口是否被占用
check_port() {
    local port=$1
    if sudo lsof -nP -a -iTCP:"$port" -sTCP:LISTEN -t >/dev/null; then
        echo "错误: 端口 $port 已被占用。请选择其他端口。"
        exit 1
    fi
}

# 告诉 Debian/Ubuntu 软件包不要自动启动后台服务器。
disable_package_autostart() {
    printf '%s\n' 'iperf3 iperf3/start_daemon boolean false' | sudo debconf-set-selections
}

# 只停止已经监听软件包默认端口的系统服务。
stop_package_listener() {
    local listeners service_pid unit
    listeners=$(sudo lsof -nP -a -c iperf3 -iTCP:"$PACKAGE_PORT" -sTCP:LISTEN -t) || return 0

    if command_exists systemctl; then
        for unit in iperf3.service iperf3-server.service; do
            service_pid=$(systemctl show --property=MainPID --value "$unit" 2>/dev/null) || continue
            if grep -Fxq "$service_pid" <<< "$listeners"; then
                echo "停止并禁用监听 $PACKAGE_PORT 端口的系统服务 $unit。"
                if [[ "$unit" == iperf3.service ]]; then
                    disable_package_autostart || return 1
                fi
                sudo systemctl disable --now "$unit"
                return $?
            fi
        done
    fi

    if [[ -x /etc/init.d/iperf3 && -r /run/iperf3.pid ]] &&
        read -r service_pid < /run/iperf3.pid && grep -Fxq "$service_pid" <<< "$listeners"; then
        echo "停止并禁用监听 $PACKAGE_PORT 端口的 iperf3 系统服务。"
        disable_package_autostart && sudo service iperf3 stop && sudo update-rc.d iperf3 disable
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

if ! command_exists lsof; then
    echo "错误: 请先安装 lsof（sudo apt install -y lsof）。" >&2
    exit 1
fi

if [[ "$PORT" != "$PACKAGE_PORT" ]]; then
    check_port "$PORT"
fi

echo "使用端口号: $PORT"

# 更新包列表（如果需要，可以取消注释以下行）
# echo "更新包列表..."
# sudo apt update

# 检查并安装 iperf3
if command_exists iperf3; then
    echo "iperf3 已经安装，跳过安装步骤。"
else
    echo "安装 iperf3..."
    if ! disable_package_autostart ||
        ! sudo env DEBIAN_FRONTEND=noninteractive apt install -y iperf3 ||
        ! command_exists iperf3; then
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
if ! EXTERNAL_IP=$(curl -4 -fsS --connect-timeout 5 --max-time 10 "$IP_LOOKUP_URL"); then
    echo "未能从 $IP_LOOKUP_URL 获取外网 IPv4 地址。请检查网络连接或服务状态。"
    exit 1
fi

# 防止服务异常时将 HTML 等内容误当成 IPv4 地址
if ! [[ "$EXTERNAL_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "IP 查询服务返回了无效的 IPv4 地址: $EXTERNAL_IP"
    exit 1
fi

echo "外网 IP 地址为: $EXTERNAL_IP"

if ! stop_package_listener; then
    echo "无法停用监听 $PACKAGE_PORT 端口的 iperf3 系统服务。" >&2
    exit 1
fi

if [[ "$PORT" == "$PACKAGE_PORT" ]]; then
    check_port "$PORT"
fi

# 输出带有外网 IP 和自定义端口的客户端命令
echo "客户端命令如下："
echo "iperf3 -c $EXTERNAL_IP -p $PORT -t 30 -P 1 -R"

# 启动 iperf3 服务器
echo "正在启动 iperf3 服务器，端口: $PORT，进程 PID: $$"
echo "按 [CTRL+C] 停止 iperf3 服务器。"
exec iperf3 -s -p "$PORT"
