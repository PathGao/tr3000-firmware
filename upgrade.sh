#!/usr/bin/env bash
# 在 Mac 上运行：备份路由器配置，下载最新 release 并校验，再保留配置刷入。
set -euo pipefail
cd "$(dirname "$0")"
router=${ROUTER:-root@192.168.1.1}

dl=$(mktemp -d)
trap 'rm -rf "$dl"' EXIT
# 复用同一条 SSH 连接，密码只输一次
ssh_opts=(-o ControlMaster=auto -o "ControlPath=$dl/ssh" -o ControlPersist=120)

gh release download -p '*-squashfs-sysupgrade.bin' -p sha256sums -D "$dl"
(cd "$dl" && shasum -a 256 -c sha256sums)

mkdir -p backups
backup=backups/backup-$(date +%Y%m%d-%H%M%S).tar.gz
ssh "${ssh_opts[@]}" "$router" 'sysupgrade -b /tmp/backup.tar.gz'
scp -O "${ssh_opts[@]}" "$router:/tmp/backup.tar.gz" "$backup"
echo "配置已备份到 $backup"

scp -O "${ssh_opts[@]}" "$dl"/*-squashfs-sysupgrade.bin "$router:/tmp/firmware.bin"
ssh "${ssh_opts[@]}" "$router" 'sysupgrade -T /tmp/firmware.bin && sysupgrade -v /tmp/firmware.bin'
