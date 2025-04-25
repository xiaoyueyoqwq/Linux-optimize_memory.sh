#!/bin/bash
# Surface Go 2 Linux 内存优化一键脚本
# 自动配置 ZRAM、memavaild、systemd-oomd，并检查冲突项

set -e

function prompt_overwrite() {
  local file="$1"
  if [ -f "$file" ]; then
    echo "检测到已存在配置文件：$file"
    read -p "是否覆盖此文件？(y/n) " choice
    if [[ $choice != "y" ]]; then
      echo "跳过 $file 配置"
      return 1
    fi
  fi
  return 0
}

# 1. 安装依赖
sudo apt update
sudo apt install -y zram-tools git make

# 2. 配置 ZRAM（/etc/default/zramswap）
prompt_overwrite "/etc/default/zramswap" && \
echo -e "ALGO=lz4\nPERCENT=100\nPRIORITY=100" | sudo tee /etc/default/zramswap
sudo systemctl restart zramswap

# 3. 配置 sysctl 参数
prompt_overwrite "/etc/sysctl.d/99-zram-optimizations.conf" && \
echo -e "vm.swappiness=60\nvm.vfs_cache_pressure=50\nvm.page-cluster=0" | sudo tee /etc/sysctl.d/99-zram-optimizations.conf
sudo sysctl --system

# 4. 安装并配置 memavaild
git clone https://github.com/hakavlad/memavaild.git
cd memavaild && ./deb/build.sh
sudo apt install -y ./deb/package.deb
cd ..

# 5. 配置 memavaild.conf
prompt_overwrite "/etc/memavaild.conf" && \
echo -e "MIN_UID=1000\nMIN_MEM_HIGH_PERCENT=15\nMAX_SWAP_USED_PERCENT=60\nDROP_CACHES=true\nSWAP_KILL=true\nACTION_CMD=\"/usr/local/bin/memcleanup.sh\"\nLOG=true" | sudo tee /etc/memavaild.conf

# 6. 创建释放内存脚本
prompt_overwrite "/usr/local/bin/memcleanup.sh" && \
echo -e "#!/bin/bash\nsync\necho 3 > /proc/sys/vm/drop_caches\nswapoff -a && swapon -a" | sudo tee /usr/local/bin/memcleanup.sh
sudo chmod +x /usr/local/bin/memcleanup.sh

# 7. 创建 systemd 触发器以修复 oomd 恢复后失效
prompt_overwrite "/etc/systemd/system/restart-oomd-after-sleep.service" && \
sudo tee /etc/systemd/system/restart-oomd-after-sleep.service > /dev/null << EOF
[Unit]
Description=Restart systemd-oomd after sleep
After=suspend.target

[Service]
Type=oneshot
ExecStart=/bin/systemctl restart systemd-oomd

[Install]
WantedBy=suspend.target
EOF

sudo systemctl enable restart-oomd-after-sleep.service

# 8. 重启相关服务
sudo systemctl restart memavaild || true
sudo systemctl restart systemd-oomd || true

# 清理构建目录
echo "清理临时目录 memavaild"
rm -rf memavaild

echo -e "\n✅ 优化完成！建议重启系统以确保所有服务生效。"

