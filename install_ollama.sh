#!/usr/bin/env bash
# -------------------------------------------------
# 离线安装 Ollama
# -------------------------------------------------
set -euo pipefail

# ---------- 变量 ----------
TAR_FILE="ollama-linux-amd64.tar.zst"
BIN_DIR="/usr/local/bin"
SERVICE_FILE="/etc/systemd/system/ollama.service"
OLLAMA_USER="ollama"
OLLAMA_GROUP="ollama"

# ---------- 1. 检查压缩包 ----------
if [[ ! -f "${TAR_FILE}" ]]; then
    echo "错误：未在当前目录找到 ${TAR_FILE}，请放置后重试。" >&2
    exit 1
fi

# ---------- 2. 创建系统用户/组 ----------
if ! id -u "${OLLAMA_USER}" >/dev/null 2>&1; then
    echo "创建系统用户 ${OLLAMA_USER} ..."
    useradd -r -s /usr/sbin/nologin -U -m -d /usr/share/ollama "${OLLAMA_USER}"
fi

# ---------- 3. 解压二进制文件 ----------
echo "解压 ${TAR_FILE} 到临时目录 ..."
TMP_DIR=$(mktemp -d)
sudo tar --use-compress-program=unzstd -xvf "${TAR_FILE}" -C "${TMP_DIR}"

# 复制可执行文件到 /usr/local/bin
echo "复制 ollama 可执行文件到 ${BIN_DIR} ..."
sudo mkdir -p "${BIN_DIR}"
sudo cp "${TMP_DIR}/bin/ollama" "${BIN_DIR}/ollama"
sudo chmod +x "${BIN_DIR}/ollama"

# 清理临时目录
rm -rf "${TMP_DIR}"

# ---------- 4. 验证可执行文件 ----------
if ! command -v ollama >/dev/null 2>&1; then
    echo "错误：ollama 未成功放入 PATH。" >&2
    exit 1
fi

echo "Ollama 版本：$(ollama -v)"

# ---------- 5. 创建 systemd 服务 ----------
echo "写入 systemd 服务文件 ${SERVICE_FILE} ..."
sudo tee "${SERVICE_FILE}" > /dev/null <<EOF
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=${BIN_DIR}/ollama serve
User=${OLLAMA_USER}
Group=${OLLAMA_GROUP}
Restart=always
RestartSec=3
Environment="PATH=\$PATH"

[Install]
WantedBy=multi-user.target
EOF

# ---------- 6. 启动并设为开机自启 ----------
echo "重新加载 systemd 并启动服务 ..."
sudo systemctl daemon-reload
sudo systemctl enable --now ollama

# ---------- 7. 最终检查 ----------
echo "检查服务状态 ..."
sudo systemctl status ollama --no-pager

echo "安装完成！"
echo "• 运行 'ollama -v' 可查看版本"
echo "• 查看日志: sudo journalctl -u ollama -f"
