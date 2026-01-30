#!/bin/bash

# OpenClaw (Clawdbot) Ultimate Installer for Raspberry Pi 3 (Ubuntu)
# 改良点：强制粉碎 ENOTEMPTY 残留 + 自动化二进制修复 + 零配置冲突
# Author: Gemini Adaptive Version (v2.2)

set -e 

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}🦞 OpenClaw Installer for Raspberry Pi 3 (Enhanced v2.2)${NC}"

# 1. 内存保护：智能扩容 Swap
setup_swap() {
    echo -e "${YELLOW}[1/7] 检查系统虚拟内存...${NC}"
    if [ $(free -m | grep Swap | awk '{print $2}') -lt 1500 ]; then
        echo -e "${CYAN}检测到物理内存较低，正在创建 2GB 临时 Swap 保护进程...${NC}"
        sudo swapoff /swapfile 2>/dev/null || true
        sudo rm -f /swapfile
        sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo -e "${GREEN}Swap 扩容完成。${NC}"
    fi
}

# 2. 增强型锁处理
resolve_apt_lock() {
    echo -e "${YELLOW}[2/7] 正在检测并解除 APT 资源锁定...${NC}"
    sudo rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock*
    sudo dpkg --configure -a
    echo -e "${GREEN}APT 锁环境已就绪。${NC}"
}

# 3. 基础工具确保
ensure_curl() {
    echo -e "${YELLOW}[3/7] 检查网络下载工具...${NC}"
    if ! command -v curl &> /dev/null; then
        sudo apt update && sudo apt install -y curl
    fi
}

# 4. 彻底环境净化 (解决 ENOTEMPTY 和 prefix 冲突的关键)
remove_old_node() {
    echo -e "${YELLOW}[4/7] 净化环境与粉碎残留配置...${NC}"
    # 强制物理删除导致 npm 报错的旧配置
    rm -f ~/.npmrc
    # 【新增】强制删除可能导致 ENOTEMPTY 报错的残留目录
    rm -rf "${HOME}/.npm-global/lib/node_modules/openclaw"
    rm -rf "${HOME}/.npm-global/lib/node_modules/.openclaw-*"
    
    if command -v node &> /dev/null || command -v npm &> /dev/null; then
        sudo apt remove --purge nodejs npm -y && sudo apt autoremove -y
        sudo rm -rf /usr/bin/node /usr/bin/nodejs /usr/bin/npm /etc/apt/sources.list.d/nodesource.list
    fi
}

# 5. 标准化安装 Node.js 22
install_node() {
    echo -e "${YELLOW}[5/7] 安装 Node.js 22 (LTS)...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt install -y nodejs
    echo -e "${GREEN}Node.js $(node -v) 部署成功。${NC}"
}

# 6. NPM 路径优化
setup_npm_global() {
    echo -e "${YELLOW}[6/7] 配置 NPM 全局二进制目录...${NC}"
    mkdir -p "${HOME}/.npm-global/bin"
    npm config set prefix "${HOME}/.npm-global"
    
    if ! grep -q ".npm-global/bin" ~/.bashrc; then
        echo 'export PATH="${HOME}/.npm-global/bin:$PATH"' >> ~/.bashrc
    fi
    export PATH="${HOME}/.npm-global/bin:$PATH"
}

# 7. 部署 OpenClaw + 强制补丁
install_openclaw() {
    echo -e "${YELLOW}[7/7] 部署 OpenClaw 并修复软链接...${NC}"
    
    # 【改良点】安装前再次确保目录为空，彻底避开 ENOTEMPTY
    rm -rf "${HOME}/.npm-global/lib/node_modules/openclaw"
    
    npm install -g openclaw@latest --no-fund --prefix "${HOME}/.npm-global"

    # 强制修复逻辑
    echo -e "${CYAN}检测命令二进制文件状态...${NC}"
    BIN_TARGET="${HOME}/.npm-global/bin/openclaw"
    CLI_SRC="${HOME}/.npm-global/lib/node_modules/openclaw/dist/cli.js"

    if [ ! -f "$BIN_TARGET" ]; then
        echo -e "${RED}执行强制手动链接补丁...${NC}"
        ln -sf "$CLI_SRC" "$BIN_TARGET"
        chmod +x "$BIN_TARGET"
    fi

    if command -v openclaw &> /dev/null || [ -f "$BIN_TARGET" ]; then
        echo -e "${GREEN}OpenClaw 安装与二进制补丁应用成功！${NC}"
    else
        echo -e "${RED}错误：部署失败。${NC}"
        exit 1
    fi
}

# --- 执行引擎 ---
setup_swap
resolve_apt_lock
ensure_curl
remove_old_node
install_node
setup_npm_global
install_openclaw

echo -e "\n${GREEN}==================================================${NC}"
echo -e "${GREEN}✨ 安装圆满完成！${NC}"
echo -e "${YELLOW}下一步必做操作：${NC}"
echo -e "1. 输入 ${CYAN}source ~/.bashrc${NC} 激活命令"
echo -e "2. 输入 ${CYAN}openclaw onboard${NC} 开始配置"
echo -e "${GREEN}==================================================${NC}"
