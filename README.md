# iperf3 一键安装与测速服务

用于在 Debian/Ubuntu 服务器上安装并启动 iperf3 服务端。脚本会自动查询服务器的公网 IP，并输出可直接在客户端执行的测速命令。

## 功能

- 自动检查并安装 `iperf3` 和 `curl`
- 支持 IPv4 和 IPv6
- 支持固定端口或自定义端口
- 启动前检查自定义端口是否已被占用
- 自动输出带公网 IP 的客户端命令
- 按 `Ctrl+C` 即可停止 iperf3 服务端

公网 IP 查询已从 IPW 切换到 [icanhazip](https://icanhazip.com/)。IPv4 和 IPv6 使用同一 HTTPS 地址，并分别通过 curl 的 `-4` 和 `-6` 参数指定网络协议。

请求启用了 HTTP 错误检查、5 秒连接超时、10 秒总超时以及返回值格式校验。

## 脚本说明

| 脚本 | 网络 | 端口 |
| --- | --- | --- |
| `install_iperf3.sh` | IPv4 | 固定为 `5022` |
| `install_iperf3_1.sh` | IPv4 | 默认 `5022`，支持 `-p` 自定义 |
| `install_iperf3_ipv6.sh` | IPv6 | 默认 `5022`，支持 `-p` 自定义 |

## 环境要求

- Debian 或 Ubuntu
- 可使用 `sudo` 的账号
- 可访问系统软件源和 icanhazip
- 自定义端口脚本使用 `lsof` 检查端口，请确保系统已安装 `lsof`

安装 `lsof`：

```bash
sudo apt update
sudo apt install -y lsof
```

## 使用方法

克隆仓库：

```bash
git clone https://github.com/amourxiao/iperf3.git
cd iperf3
```

### IPv4 固定端口

使用端口 `5022`：

```bash
bash install_iperf3.sh
```

### IPv4 自定义端口

默认使用端口 `5022`：

```bash
bash install_iperf3_1.sh
```

指定其他端口，例如 `6000`：

```bash
bash install_iperf3_1.sh -p 6000
```

如果 Debian/Ubuntu 软件包的 iperf3 后台服务已经监听默认端口 `5201`，脚本会停止该服务并禁用其开机自启，然后在指定端口以前台方式运行。按 `Ctrl+C` 即可关闭本次启动的监听。

### IPv6 自定义端口

```bash
bash install_iperf3_ipv6.sh -p 5201
```

查看参数帮助：

```bash
bash install_iperf3_1.sh -h
bash install_iperf3_ipv6.sh -h
```

## 客户端测速

脚本启动服务端后会输出类似命令：

```bash
iperf3 -c 203.0.113.10 -p 5022 -t 30 -P 1 -R
```

在另一台已安装 iperf3 的设备上执行该命令即可开始测速。常用参数：

- `-c`：服务端公网 IP
- `-p`：服务端端口
- `-t 30`：测试 30 秒
- `-P 1`：使用 1 条并行连接
- `-R`：反向测试，由服务端向客户端发送数据

## 防火墙与公网访问

请在服务器防火墙和云平台安全组中放行所用的 TCP 端口。例如使用 UFW 放行 `5022`：

```bash
sudo ufw allow 5022/tcp
```

如果服务器位于路由器之后，还需要将该端口转发到服务器。运营商级 NAT（CGNAT）环境即使能查询到公网出口 IP，也可能无法从外网直接连接；这种情况需要向运营商申请公网 IP，或使用具有端口映射能力的隧道/VPN。

## 常见问题

### 无法获取公网 IPv4

先单独测试查询服务：

```bash
curl -4 -fsS --connect-timeout 5 --max-time 10 https://icanhazip.com
```

如果失败，请检查 DNS、HTTPS 出站访问、防火墙和代理设置。

### 无法获取公网 IPv6

```bash
curl -6 -fsS --connect-timeout 5 --max-time 10 https://icanhazip.com
```

该命令要求服务器本身具备可用的 IPv6 网络；只有 IPv4 网络时会失败，请改用 IPv4 脚本。

### 客户端连接失败

依次检查：

1. iperf3 服务端进程是否仍在运行。
2. 客户端命令中的 IP 和端口是否正确。
3. 系统防火墙、云安全组是否已放行对应 TCP 端口。
4. 路由器是否完成端口转发，网络是否处于 CGNAT 环境。

## 停止服务

脚本以前台方式等待 iperf3 进程，按 `Ctrl+C` 即可停止。也可以在其他终端中执行：

```bash
pkill iperf3
```

## License

本项目尚未声明开源许可证。如需复用或分发，请先联系仓库所有者。
