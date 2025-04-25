# 🧠 Surface Go 2 Linux 内存优化指南（适用于 Zorin OS 17.3）

> 作者：xiaoyueyoqwq  
> 平台：Zorin OS 17.3（基于 Ubuntu 22.04）  
> 设备：Microsoft Surface Go 2（4GB 内存）  
> 场景：长时间运行、不重启，使用 ZRAM 替代传统 swap，追求系统流畅度与稳定性。

---

## ✨ 优化目标

- 减少系统卡顿
- 更高效利用 ZRAM 替代传统 swap
- 自动释放内存，降低人为维护成本
- 在内存压力大时智能终止进程，防止死锁

---

## 🚀 一键优化脚本功能概览 & 原理解释

该脚本将自动执行以下操作，每一步都配有原因解释：

### 1. 安装 zram-tools & memavaild
用于启用 ZRAM 压缩 swap ，和 memavaild 进行内存压力自动释放机制

```bash
sudo apt install zram-tools -y
```

---

### 2. 配置 ZRAM swap 尺寸和压缩算法
指定 100%内存用于 ZRAM，使用 lz4 压缩算法，较合适低能设备

```bash
echo -e "ALGO=lz4\nPERCENT=100\nPRIORITY=100" | sudo tee /etc/default/zramswap
sudo systemctl restart zramswap
```

---

### 3. 设置内核内存管理策略

- `vm.swappiness=60`：适度使用 swap，避免过早切换
- `vm.vfs_cache_pressure=50`：保留更多 inode/dentry 缓存，提升文件系统性能
- `vm.page-cluster=0`：降低 swap IO 跨页处理性，遮止 swap 急剧性扩散

```bash
echo -e "vm.swappiness=60\nvm.vfs_cache_pressure=50\nvm.page-cluster=0" | sudo tee /etc/sysctl.d/99-zram-optimizations.conf
sudo sysctl --system
```

---

### 4. 安装并配置 memavaild

memavaild 作为轻量级 daemon ，检测内存压力、swap 占用，在远离系统操作系统 OOM 前预先释放缓存/重启 swap

```bash
git clone https://github.com/hakavlad/memavaild.git
cd memavaild && ./deb/build.sh
sudo apt install --reinstall ./deb/package.deb
```

配置 `/etc/memavaild.conf`：

```ini
MIN_UID=1000
MIN_MEM_HIGH_PERCENT=15
MAX_SWAP_USED_PERCENT=60
DROP_CACHES=true
SWAP_KILL=true
ACTION_CMD="/usr/local/bin/memcleanup.sh"
LOG=true
```

---

### 5. 创建内存释放脚本

此脚本会将页缓存释放，重启 swap 使系统软释后系统体验更为顺畅

```bash
echo -e "#!/bin/bash\nsync\necho 3 > /proc/sys/vm/drop_caches\nswapoff -a && swapon -a" | sudo tee /usr/local/bin/memcleanup.sh
sudo chmod +x /usr/local/bin/memcleanup.sh
```

---

### 6. 重启后保障: 触发 oomd 重加载

应对单元在系统居睡/深睡后 ZRAM swap 未被 oomd 检测问题，添加重加载服务

```bash
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
```

---

### 7. 重启相关服务

```bash
sudo systemctl restart memavaild
sudo systemctl restart systemd-oomd
```

---

自此，你就拥有一套基于 ZRAM 、oomd 和 memavaild 综合智能管理内存的高效 Linux 优化配置。

如需要脚本一键优化，可以在仓库自行获取

---
