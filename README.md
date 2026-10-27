# tr3000-firmware

给 Cudy TR3000 256MB v1 打包官方 OpenWrt 固件。官方包来自 OpenWrt 官方源，PassWall2 和 Argon 来自各自作者的 GitHub Release，下载后按 GitHub 给的 sha256 校验。固件里不带任何配置。

## 打包

GitHub 上进入 Actions → Build → Run workflow。每次会用 25.12 系列最新正式版和最新的 Argon，PassWall2 版本按 `config.env` 锁定。成功后发布一个 release，说明里写着各组件版本。

- 官方包：改 `packages.txt`。
- 第三方包版本：改 `config.env`。

## 升级

```bash
./upgrade.sh
```

它会下载最新 release 并校验 sha256，把路由器配置备份到 `backups/`，再保留配置刷入。路由器密码只输一次。
