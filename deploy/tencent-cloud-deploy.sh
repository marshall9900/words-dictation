#!/bin/bash
#===============================================
# Words Dictation v2 - 腾讯云一键部署脚本
# 适用于腾讯云 CVM / Lighthouse
#===============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用 root 用户或 sudo 运行此脚本"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        log_error "无法检测操作系统"
        exit 1
    fi
    log_info "检测到操作系统: $OS $VER"
}

# 检测腾讯云环境
detect_tencent_cloud() {
    if curl -s --max-time 2 http://169.254.0.23/openstack/latest/meta_data.json > /dev/null 2>&1; then
        TC_ENV="tencentcloud"
        log_ok "检测到腾讯云环境"
    elif curl -s --max-time 2 http://100.100.100.254/openstack/latest/meta_data.json > /dev/null 2>&1; then
        TC_ENV="tencentcloud"
        log_ok "检测到腾讯云环境（云实验室）"
    else
        TC_ENV="generic"
        log_warn "未检测到腾讯云元数据服务，将按通用云服务器配置"
    fi
}

# 获取腾讯云地域
get_tencent_region() {
    if curl -s --max-time 2 http://169.254.0.23/openstack/latest/meta_data.json 2>/dev/null | grep -q region; then
        REGION=$(curl -s http://169.254.0.23/openstack/latest/meta_data.json 2>/dev/null | grep -o '"region"[^,]*' | cut -d'"' -f4 || echo "ap-guangzhou")
        log_info "腾讯云地域: $REGION"
    else
        REGION="ap-guangzhou"
    fi
}

# 配置腾讯云镜像源
configure_mirrors() {
    log_info "配置腾讯云镜像源..."
    
    if [[ "$OS" == "ubuntu" ]]; then
        # 腾讯云 Ubuntu 镜像源
        mv /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true
        cat > /etc/apt/sources.list << 'EOF'
deb http://mirrors.tencentyun.com/ubuntu/ jammy main restricted universe multiverse
deb http://mirrors.tencentyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://mirrors.tencentyun.com/ubuntu/ jammy-security main restricted universe multiverse
EOF
        apt-get update -qq
        
    elif [[ "$OS" == "centos" ]] || [[ "$OS" == "rocky" ]] || [[ "$OS" == "almalinux" ]]; then
        # 腾讯云 CentOS 镜像源
        sed -e 's|^mirrorlist=|#mirrorlist=|g' \
            -e 's|^#baseurl=http://mirror.centos.org|baseurl=http://mirrors.cloud.tencent.com|g' \
            -i /etc/yum.repos.d/CentOS-*.repo /etc/yum.repos.d Rocky-*.repo 2>/dev/null || true
        yum makecache -q
    fi
    
    log_ok "镜像源配置完成"
}

# 安装 Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_ok "Docker 已安装: $(docker --version)"
        return
    fi
    
    log_info "安装 Docker..."
    
    if [[ "$OS" == "ubuntu" ]]; then
        apt-get install -y ca-certificates curl gnupg lsb-release
        
        # 添加 Docker GPG 密钥
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        
        # 添加 Docker 仓库
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
        
        apt-get update -qq
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
    elif [[ "$OS" == "centos" ]] || [[ "$OS" == "rocky" ]] || [[ "$OS" == "almalinux" ]]; then
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    fi
    
    # 启动 Docker
    systemctl enable docker --now
    log_ok "Docker 安装完成: $(docker --version)"
}

# 安装 Docker Compose (standalone)
install_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        log_ok "Docker Compose 已安装: $(docker-compose --version)"
        return
    fi
    
    log_info "安装 Docker Compose..."
    
    # 使用腾讯云 CDN 加速下载
    curl -fsSL https://mirrors.cloud.tencent.com/docker-toolbox/linux/compose -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # 如果腾讯云镜像不可用，使用官方源
    if ! docker-compose --version &> /dev/null; then
        curl -fsSL https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    log_ok "Docker Compose 安装完成: $(docker-compose --version)"
}

# 配置防火墙 - 开放所需端口
configure_firewall() {
    log_info "配置防火墙端口..."
    
    # 检测防火墙类型
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian - UFW
        ufw --force enable
        ufw allow 22/tcp comment 'SSH'
        ufw allow 80/tcp comment 'HTTP'
        ufw allow 443/tcp comment 'HTTPS'
        ufw allow 3001/tcp comment 'Backend API'
        ufw reload
        log_ok "UFW 防火墙配置完成"
        
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/Rocky - firewalld
        systemctl enable firewalld --now
        firewall-cmd --permanent --add-port=22/tcp
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --permanent --add-port=3001/tcp
        firewall-cmd --reload
        log_ok "firewalld 防火墙配置完成"
    else
        log_warn "未检测到 UFW 或 firewalld，跳过防火墙配置"
        log_warn "请手动在腾讯云安全组中开放端口: 22, 80, 443, 3001"
    fi
}

# 创建部署目录结构
create_directories() {
    log_info "创建部署目录..."
    
    DEPLOY_DIR="/opt/words-dictation"
    mkdir -p $DEPLOY_DIR/{uploads,logs,ssl}
    chmod -R 755 $DEPLOY_DIR
    
    log_ok "部署目录: $DEPLOY_DIR"
}

# 复制部署文件
copy_deploy_files() {
    log_info "复制部署文件..."
    
    DEPLOY_DIR="/opt/words-dictation"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 复制 docker-compose 配置
    cp $SCRIPT_DIR/docker-compose.tencent.yml $DEPLOY_DIR/docker-compose.yml
    
    # 复制 nginx 配置
    cp $SCRIPT_DIR/nginx.conf $DEPLOY_DIR/nginx.conf
    
    # 复制环境变量文件
    cp $SCRIPT_DIR/.env.tencent $DEPLOY_DIR/.env
    
    # 创建 backend 目录并复制代码
    mkdir -p $DEPLOY_DIR/backend
    if [[ -d "/root/.openclaw/workspace/src/words-dictation-v2/backend" ]]; then
        cp -r /root/.openclaw/workspace/src/words-dictation-v2/backend/* $DEPLOY_DIR/backend/
    fi
    
    # 创建 uploads 软链接
    ln -sfn $DEPLOY_DIR/uploads $DEPLOY_DIR/backend/uploads 2>/dev/null || true
    
    log_ok "文件复制完成"
}

# 配置系统服务 (可选)
configure_systemd() {
    log_info "配置系统服务..."
    
    cat > /etc/systemd/system/words-dictation.service << 'EOF'
[Unit]
Description=Words Dictation Backend
After=network.target mysql.service redis.service

[Service]
Type=oneshot
WorkingDirectory=/opt/words-dictation
ExecStart=/usr/local/bin/docker-compose -f /opt/words-dictation/docker-compose.yml up -d
ExecStop=/usr/local/bin/docker-compose -f /opt/words-dictation/docker-compose.yml down
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable words-dictation.service
    log_ok "系统服务配置完成"
}

# 获取 Let's Encrypt SSL 证书
get_ssl_cert() {
    log_info "申请 SSL 证书..."
    
    DOMAIN=${DOMAIN:-""}
    
    if [[ -z "$DOMAIN" ]]; then
        log_warn "未设置 DOMAIN 环境变量，跳过 SSL 证书申请"
        log_warn "请稍后使用 certbot --nginx -d your-domain.com 命令手动申请"
        return
    fi
    
    # 安装 certbot
    if ! command -v certbot &> /dev/null; then
        if [[ "$OS" == "ubuntu" ]]; then
            apt-get install -y certbot python3-certbot-nginx
        elif [[ "$OS" == "centos" ]] || [[ "$OS" == "rocky" ]] || [[ "$OS" == "almalinux" ]]; then
            yum install -y certbot python3-certbot-nginx
        fi
    fi
    
    # 开放 80 端口（Let's Encrypt 验证用）
    if command -v ufw &> /dev/null; then
        ufw allow 80/tcp
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --add-port=80/tcp
    fi
    
    # 申请证书
    certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN
    
    # 配置自动续期
    echo "0 0 * * * certbot renew --quiet" | crontab -
    
    log_ok "SSL 证书申请完成"
}

# 启动服务
start_services() {
    log_info "启动服务..."
    
    cd /opt/words-dictation
    
    # 拉取最新镜像
    docker-compose pull
    
    # 启动服务
    docker-compose up -d --build
    
    # 等待服务健康检查
    log_info "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    if docker-compose ps | grep -q "Up"; then
        log_ok "服务启动成功"
    else
        log_error "服务启动失败，请检查日志"
        docker-compose logs
        exit 1
    fi
}

# 验证部署
verify_deployment() {
    log_info "验证部署..."
    
    # 检查容器状态
    echo ""
    echo "=== 容器状态 ==="
    docker-compose -f /opt/words-dictation/docker-compose.yml ps
    
    echo ""
    echo "=== 服务健康检查 ==="
    
    # 检查后端 API
    if curl -sf http://localhost:3001/api/health &>/dev/null; then
        log_ok "后端 API: http://localhost:3001 - 运行正常"
    else
        log_warn "后端 API 响应异常，请检查日志"
    fi
    
    # 检查 Nginx
    if command -v nginx &> /dev/null; then
        if nginx -t &>/dev/null; then
            log_ok "Nginx 配置正常"
        else
            log_warn "Nginx 配置有误，请检查"
        fi
    fi
    
    echo ""
    echo "=== 访问地址 ==="
    echo "  后端 API: http://YOUR_SERVER_IP:3001"
    echo "  如配置 Nginx: http://YOUR_DOMAIN"
}

# 显示帮助信息
show_help() {
    echo ""
    echo "=============================================="
    echo "  Words Dictation v2 - 腾讯云一键部署脚本"
    echo "=============================================="
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --with-ssl        申请 SSL 证书"
    echo "  --domain DOMAIN   指定域名（配合 --with-ssl 使用）"
    echo "  --skip-firewall   跳过防火墙配置"
    echo "  --help            显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                                    # 基础部署"
    echo "  $0 --with-ssl --domain example.com    # 带 SSL 证书部署"
    echo ""
    echo "环境变量:"
    echo "  DOMAIN        域名（用于 SSL 证书申请）"
    echo "  MYSQL_ROOT    MySQL root 密码"
    echo "  JWT_SECRET    JWT 密钥"
    echo ""
}

# 主函数
main() {
    echo ""
    echo "=============================================="
    echo "  Words Dictation v2 - 腾讯云一键部署"
    echo "=============================================="
    echo ""
    
    # 解析命令行参数
    SKIP_FIREWALL=false
    WITH_SSL=false
    DOMAIN=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --with-ssl)
                WITH_SSL=true
                shift
                ;;
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --skip-firewall)
                SKIP_FIREWALL=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    export DOMAIN
    
    check_root
    detect_os
    detect_tencent_cloud
    get_tencent_region
    
    echo ""
    echo "即将执行以下步骤:"
    echo "  1. 配置镜像源 (腾讯云 CDN)"
    echo "  2. 安装 Docker + Docker Compose"
    echo "  3. 配置防火墙 (开放 22, 80, 443, 3001)"
    echo "  4. 创建部署目录结构"
    echo "  5. 复制部署文件"
    echo "  6. 启动服务"
    echo ""
    read -p "按 Enter 键继续，或 Ctrl+C 取消..."
    
    configure_mirrors
    install_docker
    install_docker_compose
    
    if [[ "$SKIP_FIREWALL" == "false" ]]; then
        configure_firewall
    fi
    
    create_directories
    copy_deploy_files
    
    if [[ "$WITH_SSL" == "true" ]]; then
        get_ssl_cert
    fi
    
    start_services
    verify_deployment
    
    echo ""
    echo "=============================================="
    echo "  部署完成!"
    echo "=============================================="
    echo ""
    echo "下一步操作:"
    echo "  1. 编辑 /opt/words-dictation/.env 配置密钥"
    echo "  2. 配置腾讯云安全组 (开放 80, 443)"
    echo "  3. 配置域名解析"
    echo "  4. 如需 SSL: certbot --nginx -d your-domain.com"
    echo ""
    echo "常用命令:"
    echo "  查看日志:    docker-compose -f /opt/words-dictation/docker-compose.yml logs -f"
    echo "  重启服务:    docker-compose -f /opt/words-dictation/docker-compose.yml restart"
    echo "  停止服务:    docker-compose -f /opt/words-dictation/docker-compose.yml down"
    echo "  更新部署:    cd /opt/words-dictation && git pull && docker-compose up -d --build"
    echo ""
}

main "$@"
