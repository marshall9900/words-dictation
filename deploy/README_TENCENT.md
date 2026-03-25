# Words Dictation v2 - 腾讯云部署指南

> 适用于腾讯云 CVM / Lighthouse 一键部署

---

## 📋 目录

1. [腾讯云购买指引](#1-腾讯云购买指引)
2. [安全组配置](#2-安全组配置)
3. [域名解析配置](#3-域名解析配置)
4. [部署步骤](#4-部署步骤)
5. [SSL 证书申请](#5-ssl-证书申请)
6. [验证方法](#6-验证方法)
7. [常用运维命令](#7-常用运维命令)
8. [故障排查](#8-故障排查)

---

## 1. 腾讯云购买指引

### 推荐配置

| 配置项 | 推荐选择 | 说明 |
|--------|---------|------|
| **产品** | Lighthouse 轻量应用服务器 | 性价比高，简化运维 |
| **镜像** | Ubuntu 22.04 LTS | 长期支持，稳定可靠 |
| **套餐** | 2核4G / 4核8G | 根据用户规模选择 |
| **流量** | 每月 500GB - 2TB | 绘本音频文件较大，建议充足 |
| **硬盘** | 50GB SSD | 最低配置 |
| **公网** | 独立 IP + 流量包 | 必需 |

### 为什么不推荐 CVM？

Lighthouse 更适合此场景：
- ✅ 开箱即用，自动初始化
- ✅ 成本更低（月均 60-150 元）
- ✅ 自动配置 SSH 和防火墙
- ✅ 内置应用市场（可选）

### 购买后必做

1. **保存好管理员密码** 或绑定 SSH 密钥
2. **记录公网 IP 地址**（如 `1.2.3.4`）
3. **重置 root 密码**（首次登录后立即修改）

---

## 2. 安全组配置

安全组是腾讯云的**防火墙**，必须正确配置。

### 必需入站规则

| 协议 | 端口 | 来源 | 用途 |
|------|------|------|------|
| TCP | 22 | 你的 IP | SSH 管理 |
| TCP | 80 | 0.0.0.0/0 | HTTP (Let's Encrypt 验证) |
| TCP | 443 | 0.0.0.0/0 | HTTPS |
| TCP | 3001 | 127.0.0.1 | 后端 API (仅本地访问) |

### 配置步骤

1. 进入 **云服务器控制台** → **安全组**
2. 选择或创建安全组
3. 添加入站规则：

```
# 规则 1: SSH
协议: TCP
端口: 22
来源: 你的 IP/32 (或 0.0.0.0/0 如需任意访问)
策略: 允许

# 规则 2: HTTP
协议: TCP
端口: 80
来源: 0.0.0.0/0
策略: 允许

# 规则 3: HTTPS
协议: TCP
端口: 443
来源: 0.0.0.0/0
策略: 允许
```

4. 将安全组**绑定到实例**

### ⚠️ 重要提醒

- **禁止** 将 3001 端口对公网开放（后端 API 只能通过 Nginx 访问）
- SSH 端口 22 建议**限制来源 IP**（仅你的家庭/办公 IP）
- 如使用域名访问，80 和 443 必须对所有 IP 开放（Let's Encrypt 验证需要）

---

## 3. 域名解析配置

### 购买域名（可选但推荐）

1. 在腾讯云或阿里云购买域名（如 `wordsdict.cn`）
2. 价格：约 20-50 元/年

### 配置 DNS 解析

1. 进入 **DNSPod**（腾讯云 DNS 服务）
2. 添加记录：

| 记录类型 | 主机记录 | 记录值 | TTL |
|---------|---------|--------|-----|
| A | @ | 你的服务器 IP | 600 |
| A | www | 你的服务器 IP | 600 |

3. 等待 10-30 分钟生效

### 验证 DNS

```bash
ping your-domain.com
nslookup your-domain.com
```

---

## 4. 部署步骤

### 方式一：全自动部署（推荐）

```bash
# 1. SSH 登录服务器
ssh root@你的服务器IP

# 2. 下载部署脚本
cd /opt
git clone https://github.com/your-repo/words-dictation-v2.git
cd words-dictation-v2/deploy

# 3. 设置执行权限
chmod +x tencent-cloud-deploy.sh

# 4. 运行部署脚本
DOMAIN=your-domain.com ./tencent-cloud-deploy.sh

# 5. 按提示完成部署
```

### 方式二：手动分步部署

#### Step 1: 安装依赖

```bash
# 更新系统
apt update && apt upgrade -y

# 安装 Docker
curl -fsSL https://get.docker.com | bash

# 安装 Docker Compose
curl -fsSL https://get.docker.com | bash
docker-compose --version

# 安装 Nginx
apt install -y nginx certbot python3-certbot-nginx
```

#### Step 2: 配置环境变量

```bash
cd /opt/words-dictation
cp deploy/.env.tencent .env

# 编辑 .env 填写真实配置
vim .env
```

**必须修改的配置：**

```env
# JWT 密钥 - 必须修改！使用随机字符串
JWT_SECRET=生成一个32位以上的随机字符串

# 数据库密码 - 必须修改！
DB_PASSWORD=你的强密码

# MySQL 用户
DB_USER=words_user

# 腾讯云 COS (可选)
TENCENT_SECRET_ID=你的SecretId
TENCENT_SECRET_KEY=你的SecretKey
COS_BUCKET=你的COS桶名
COS_REGION=ap-guangzhou

# MiniMax API (可选)
MINIMAX_API_KEY=你的APIKey
MINIMAX_GROUP_ID=你的GroupId
```

#### Step 3: 启动服务

```bash
# 创建数据目录
mkdir -p /opt/words-dictation/data/{mysql,redis}
mkdir -p /opt/words-dictation/logs
mkdir -p /opt/words-dictation/uploads

# 复制配置文件
cp deploy/docker-compose.tencent.yml /opt/words-dictation/docker-compose.yml
cp deploy/nginx.conf /opt/words-dictation/nginx.conf

# 启动所有服务
cd /opt/words-dictation
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

#### Step 4: 配置 Nginx

```bash
# 复制 Nginx 配置
cp /opt/words-dictation/nginx.conf /etc/nginx/sites-available/words-dictation
ln -sf /etc/nginx/sites-available/words-dictation /etc/nginx/sites-enabled/

# 测试配置
nginx -t

# 重载 Nginx
systemctl reload nginx

# 设置开机自启
systemctl enable nginx
```

---

## 5. SSL 证书申请

### 使用 Let's Encrypt（免费，推荐）

```bash
# 申请证书（需域名已解析）
certbot --nginx -d your-domain.com

# 自动续期测试
certbot renew --dry-run

# 设置自动续期（已自动配置）
```

### 使用腾讯云 SSL 证书（付费）

1. 在 **腾讯云 SSL 证书控制台** 购买/申请
2. 下载 Nginx 格式证书
3. 上传到服务器：

```bash
mkdir -p /etc/nginx/ssl
# 上传证书文件到 /etc/nginx/ssl/
```

4. 修改 Nginx 配置中的证书路径

---

## 6. 验证方法

### 检查服务状态

```bash
# 检查容器状态
docker-compose ps

# 检查健康端点
curl http://localhost:3001/api/health

# 检查 Nginx
nginx -t
systemctl status nginx
```

### 预期输出

```bash
$ curl http://localhost:3001/api/health
{"status":"ok","timestamp":1699999999}
```

### 浏览器访问测试

| 地址 | 预期结果 |
|------|---------|
| `http://服务器IP:3001/api/health` | `{"status":"ok"}` |
| `http://服务器IP/api/health` | `{"status":"ok"}`（经 Nginx） |
| `https://你的域名/api/health` | `{"status":"ok"}`（HTTPS） |

---

## 7. 常用运维命令

### 服务管理

```bash
# 查看所有服务状态
docker-compose -f /opt/words-dictation/docker-compose.yml ps

# 查看实时日志
docker-compose -f /opt/words-dictation/docker-compose.yml logs -f

# 查看后端日志
docker logs words-backend -f

# 查看 MySQL 日志
docker logs words-mysql -f

# 重启所有服务
docker-compose -f /opt/words-dictation/docker-compose.yml restart

# 重启单个服务
docker-compose -f /opt/words-dictation/docker-compose.yml restart backend

# 停止所有服务
docker-compose -f /opt/words-dictation/docker-compose.yml down

# 更新部署（代码更新后）
cd /opt/words-dictation
git pull
docker-compose up -d --build
```

### 数据库操作

```bash
# 连接 MySQL
docker exec -it words-mysql mysql -u root -p

# 备份数据库
docker exec words-mysql mysqldump -u root -p$DB_PASSWORD $DB_NAME > backup.sql

# 恢复数据库
docker exec -i words-mysql mysql -u root -p$DB_PASSWORD $DB_NAME < backup.sql
```

### 日志管理

```bash
# 查看错误日志
tail -100 /var/log/nginx/error.log

# 清理 Docker 日志（防止磁盘占满）
docker system prune -f
```

### 磁盘清理

```bash
# 查看磁盘使用
df -h

# 查看 Docker 占用
docker system df

# 清理未使用的 Docker 资源
docker system prune -a -f --volumes
```

### 系统更新

```bash
# 安全更新
apt update && apt upgrade -y

# 重启服务器
reboot
```

---

## 8. 故障排查

### 常见问题

#### Q1: 容器启动失败

```bash
# 查看详细日志
docker-compose -f /opt/words-dictation/docker-compose.yml logs backend

# 常见原因：
# - 端口被占用：检查 3001/3306/6379 是否被占用
# - 内存不足：docker stats 查看资源使用
# - .env 配置错误：检查环境变量是否正确
```

#### Q2: 数据库连接失败

```bash
# 检查 MySQL 是否健康
docker exec words-mysql mysqladmin ping -h localhost -u root -p

# 检查连接配置
docker exec words-backend env | grep DB_
```

#### Q3: 前端无法访问 API

```bash
# 检查 Nginx 是否运行
systemctl status nginx

# 检查 Nginx 日志
tail -50 /var/log/nginx/error.log

# 检查反向代理是否配置正确
curl -v http://localhost/api/health
```

#### Q4: SSL 证书申请失败

```bash
# 确保 80 端口开放
curl -I http://your-domain.com

# 检查域名解析
nslookup your-domain.com

# 查看 certbot 日志
tail -50 /var/log/letsencrypt/letsencrypt.log
```

#### Q5: 内存不足 (OOM)

```bash
# 查看内存使用
free -h

# 查看容器内存使用
docker stats

# 减少 Docker 资源限制（编辑 docker-compose.yml）
# 或添加 swap
```

### 完整重装

```bash
# 停止并删除所有容器和数据
cd /opt/words-dictation
docker-compose down -v

# 删除所有数据（谨慎！）
rm -rf data/ logs/ uploads/

# 重新开始
./deploy/tencent-cloud-deploy.sh
```

---

## 📞 技术支持

如遇到问题，请提供以下信息：

1. 服务器操作系统和版本
2. `docker-compose ps` 输出
3. `docker-compose logs` 相关日志
4. `.env` 中已脱敏的配置（不含密钥）

---

## 🔄 更新日志

- **2024-03**: 初始版本
- 支持 Ubuntu 22.04 LTS
- 支持 Docker + Docker Compose
- 支持 MySQL 8.0 + Redis 7
- 支持 Let's Encrypt SSL
