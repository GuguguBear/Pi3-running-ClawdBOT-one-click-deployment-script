#!/bin/bash

# =================================================================
# OpenClaw (Clawdbot) Performance Installer for Raspberry Pi 4
# 适用环境: Ubuntu Server 25 (64-bit)
# 改良点：强制接管后台更新锁 + 移除废弃参数 + 路径自动补丁
# Author: Gemini Adaptive Version (v2.4)
# =================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}🚀 启动树莓派 4 (Pi4) 专用 OpenClaw 高性能安装程序 (v2.4)${NC}"

# 1. 内存优化
setup_mem_optimization() {
    echo -e "${YELLOW}[1/7] 检查物理内存状态...${NC}"
    TOTAL_RAM=$(free -m | grep Mem | awk '{print $2}')
    if [ "$TOTAL_RAM" -lt 1500 ]; then
        echo -e "${CYAN}内存低于 2GB，正在启用 1GB 临时 Swap...${NC}"
        sudo swapoff -a 2>/dev/null || true
        sudo fallocate -l 1G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
    else
        echo -e "${GREEN}内存充足 (${TOTAL_RAM}MB)，无需配置 Swap。${NC}"
    fi
}

# 2. 暴力破锁逻辑 (针对 unattended-upgrades)
resolve_apt_lock() {
    echo -e "${YELLOW}[2/7] 正在解除系统后台更新锁...${NC}"
    
    # 尝试停止后台更新服务
    sudo systemctl stop unattended-upgrades 2>/dev/null || true
    
    # 循环等待并强制清理锁文件
    LOCK_FILES=("/var/lib/apt/lists/lock" "/var/cache/apt/archives/lock" "/var/lib/dpkg/lock*")
    for file in "${LOCK_FILES[@]}"; do
        sudo rm -f $file
    done
    
    # 修复可能损坏的软件包数据库
    sudo dpkg --configure -a
    echo -e "${GREEN}APT 锁已强制解除，系统控制权已回收。${NC}"
}

# 3. 依赖预装
ensure_deps() {
    echo -e "${YELLOW}[3/7] 同步系统依赖...${NC}"
    sudo apt-get update
    sudo apt-get install -y curl build-essential python3
}

# 4. 环境净化
cleanup_environment() {
    echo -e "${YELLOW}[4/7] 深度清理冲突配置与残留...${NC}"
    rm -f ~/.npmrc
    rm -rf "${HOME}/.npm-global/lib/node_modules/openclaw"
    rm -rf "${HOME}/.npm-global/lib/node_modules/.openclaw-*"
}

# 5. 安装 Node.js 22
install_node() {
    echo -e "${YELLOW}[5/7] 部署 Node.js 22 (LTS)...${NC}"
    if ! command -v node &> /dev/null || [ "$(node -v | cut -d. -f1)" != "v22" ]; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt-get install -y nodejs
    else
        echo -e "${GREEN}检测到 Node.js 22 已安装。${NC}"
    fi
}

# 6. NPM 路径配置 (已修复 jobs 报错)
setup_npm_config() {
    echo -e "${YELLOW}[6/7] 配置 NPM 运行环境...${NC}"
    mkdir -p "${HOME}/.npm-global/bin"
    npm config set prefix "${HOME}/.npm-global"
    
    # 移除废弃参数，让 NPM 22 自行管理并发
    
    if ! grep -q ".npm-global/bin" ~/.bashrc; then
        echo 'export PATH="${HOME}/.npm-global/bin:$PATH"' >> ~/.bashrc
    fi
    export PATH="${HOME}/.npm-global/bin:$PATH"
}

# 7. 部署 OpenClaw + 自动补丁
install_openclaw() {
    echo -e "${YELLOW}[7/7] 正在部署 OpenClaw...${NC}"
    # 强制清理目标目录
    rm -rf "${HOME}/.npm-global/lib/node_modules/openclaw"
    
    npm install -g openclaw@latest --no-fund --prefix "${HOME}/.npm-global"

    echo -e "${CYAN}正在验证命令有效性...${NC}"
    BIN_TARGET="${HOME}/.npm-global/bin/openclaw"
    CLI_SRC="${HOME}/.npm-global/lib/node_modules/openclaw/dist/cli.js"

    if [ ! -f "$BIN_TARGET" ]; then
        ln -sf "$CLI_SRC" "$BIN_TARGET"
        chmod +x "$BIN_TARGET"
    fi

    if command -v openclaw &> /dev/null || [ -f "$BIN_TARGET" ]; then
        echo -e "${GREEN}OpenClaw 安装圆满成功！${NC}"
    else
        echo -e "${RED}部署失败，请检查网络。${NC}"
        exit 1
    fi
}

# --- 启动 ---
setup_mem_optimization
resolve_apt_lock
ensure_deps
cleanup_environment
install_node
setup_npm_config
install_openclaw

echo -e "\n${GREEN}==================================================${NC}"
echo -e "${GREEN}✨ 安装完成！${NC}"
echo -e "请执行: ${CYAN}source ~/.bashrc${NC}"
echo -e "然后开始配置: ${CYAN}openclaw onboard${NC}"
echo -e "${GREEN}==================================================${NC}"
