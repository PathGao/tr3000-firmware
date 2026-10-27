#!/usr/bin/env bash
# 用官方 Image Builder 拼出 sysupgrade 固件，加上 config.env 指定的第三方包。需要 Linux x86_64、gh、jq。
set -euo pipefail
cd "$(dirname "$0")"
. ./config.env

work=$PWD/work
out=$PWD/out
rm -rf "$work" "$out"
mkdir -p "$work/extra" "$out"

# 该系列最新的正式版，跳过 -rc
version=$(curl -fsS https://downloads.openwrt.org/.versions.json |
  jq -r --arg s "$SERIES." '.versions_list[] | select(startswith($s) and (contains("-") | not))' |
  sort -V | tail -n1)
[ -n "$version" ] || { echo "找不到 $SERIES 的正式版" >&2; exit 1; }

base=https://downloads.openwrt.org/releases/$version/targets/$TARGET
ib=openwrt-imagebuilder-$version-${TARGET/\//-}.Linux-x86_64.tar.zst
curl -fsSL -o "$work/sha256sums" "$base/sha256sums"
curl -fsSL -o "$work/$ib" "$base/$ib"
(cd "$work" && grep " \*$ib\$" sha256sums | sha256sum -c -)
tar -C "$work" --zstd -xf "$work/$ib"
ibdir=$work/${ib%.tar.zst}

release() {
  if [ "$2" = latest ]; then gh api "repos/$1/releases/latest"; else gh api "repos/$1/releases/tags/$2"; fi
}

# 下载 release 里名字匹配正则的资源，按 GitHub 给的 sha256 校验；一个都没匹配到就失败
fetch() {
  local json=$1 re=$2 n=0 name digest url
  while read -r name digest url; do
    curl -fsSL -o "$work/extra/$name" "$url"
    echo "${digest#sha256:}  $work/extra/$name" | sha256sum -c -
    n=$((n + 1))
  done < <(jq -r --arg re "$re" '.assets[] | select(.name | test($re)) | "\(.name) \(.digest) \(.browser_download_url)"' <<<"$json")
  [ "$n" -gt 0 ] || { echo "没有匹配 $re 的资源" >&2; exit 1; }
}

pw=$(release Openwrt-Passwall/openwrt-passwall2 "$PASSWALL2_TAG")
fetch "$pw" '^luci-(app|i18n)-passwall2(-zh-cn)?-[0-9].*\.apk$'
fetch "$pw" "packages_apk_${ARCH}\\.zip\$"
# zip 里其余的包官方源都有，只取官方没有的两个
unzip -j -o "$work"/extra/*packages_apk_"$ARCH".zip 'geoview-*.apk' 'tcping-*.apk' -d "$work/extra"
rm "$work"/extra/*.zip

argon=$(release jerrykuku/luci-theme-argon "$ARGON_TAG")
fetch "$argon" '^luci-(theme-argon|app-argon-config|i18n-argon-config-zh-cn)-[0-9].*\.apk$'

cp "$work"/extra/*.apk "$ibdir/packages/"

packages="$(grep -Ev '^\s*(#|$)' packages.txt | xargs)"
packages+=" luci-app-passwall2 luci-i18n-passwall2-zh-cn geoview tcping"
packages+=" luci-theme-argon luci-app-argon-config luci-i18n-argon-config-zh-cn"

make -C "$ibdir" image PROFILE="$PROFILE" PACKAGES="$packages" BIN_DIR="$out"

cd "$out"
sysupgrade=$(ls ./*-squashfs-sysupgrade.bin)
sha256sum "${sysupgrade#./}" >sha256sums
xray=$(grep '^xray-core ' ./*.manifest)
cat >notes.md <<EOF
- OpenWrt $version
- PassWall2 $(jq -r .tag_name <<<"$pw")
- Argon $(jq -r .tag_name <<<"$argon")
- ${xray}
EOF
echo "$version" >version
cat notes.md
