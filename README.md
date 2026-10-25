# ThinkBook X G2 IAH (21TU) 扬声器 DKMS 修复

适用：Lenovo ThinkBook X G2 IAH / MTM 21TU  
系统：Debian 13 (trixie)，内核 6.12.x  
问题：ALC287 + 4 颗 CS35L41（CSC3551, I2C）功放未绑定，扬声器无声

这个包**不更新内核镜像**，只做两件事：

1. 用 DKMS 重新编译 `snd-hda-scodec-cs35l41` 模块，补上内核 6.12.113 缺少的 `17AA3929` 配置表项；
2. 通过 `hda_model=1028:0c4d` 强制走 6.12 已有的四功放 I2C fixup。

内核版本、GRUB 和已安装内核包都不动。

## 文件说明

```
thinkbook-audio/
├── dkms-src/                 DKMS 源码（4 个 .c + 局部头文件 + Makefile + dkms.conf）
├── install.sh                安装依赖、注册 DKMS、编译并安装模块
├── uninstall.sh              移除 DKMS 模块和 modprobe 配置
├── audio-fix-on.sh           打开四功放 fixup（写入 hda_model 参数）
├── audio-fix-off.sh          关闭四功放 fixup（模块保留但不生效）
├── verify.sh                 只读状态检查
├── patch/                    对 6.12.113 源码的两处改动
├── prebuilt/                 本机编译产物（6.12.113）和 BUILD-INFO
├── install.log               本次安装/编译日志
└── README.md
```

## 本机构建结果（2026-10-25）

- 内核：`6.12.113+deb13-amd64`
- DKMS：`snd-hda-scodec-cs35l41-thinkbook/1.0, 6.12.113+deb13-amd64, x86_64: installed`
- 模块路径：`/lib/modules/6.12.113+deb13-amd64/updates/dkms/snd-hda-scodec-cs35l41.ko.xz`
- 三个模块的 vermagic 均匹配，已用 DKMS MOK 密钥签名
- 源码中已确认存在 `17AA3929` 表项
- **重启后验证通过：4 个 i2c 功放全部绑定**
- PipeWire 播放 660Hz 测试音 `exit 0`，播放时 4 个功放 runtime 状态均为 `active`
- 编译产物备份在 `prebuilt/6.12.113+deb13-amd64/`
- 验证记录：`post-reboot-check.txt`、`post-reboot-verify.txt`

## 安装

因为需要 root，二选一：

```bash
# 在终端里，先进入包含本 README 的目录
cd thinkbook-audio
sudo ./install.sh              # 默认安装并启用
# 或
sudo ./install.sh --no-enable  # 只装模块，先不启用
```

或者用图形密码框（polkit），在脚本所在目录执行：

```bash
pkexec "$PWD/install.sh"
```

安装脚本会：

- 安装 `dkms build-essential linux-headers-amd64 linux-headers-<当前内核> dwarves libelf-dev libssl-dev firmware-cirrus`
- 把源码复制到 `/usr/src/snd-hda-scodec-cs35l41-thinkbook-1.0`
- `dkms add/build/install`（只对 6.12.x 构建）
- 默认写入 `/etc/modprobe.d/thinkbook-audio.conf`：
  ```
  options snd_sof_intel_hda_generic hda_model=1028:0c4d
  ```
- `update-initramfs`

完成后**重启**。

## 开关

模块和功能是分开的：DKMS 模块装上后，只有加了 `hda_model=1028:0c4d` 才会绑定四颗功放。

```bash
sudo ./audio-fix-off.sh   # 关闭，重启后恢复原状（模块还在）
sudo ./audio-fix-on.sh    # 打开，重启后生效
```

两个脚本都只改 `/etc/modprobe.d/thinkbook-audio.conf` 并重建 initramfs。

## 验证

```bash
./verify.sh
```

重点看：

1. `dkms status` 里有 `snd-hda-scodec-cs35l41-thinkbook/1.0, 6.12.113+deb13-amd64: installed`
2. `modinfo -n snd-hda-scodec-cs35l41` 指向 `/lib/modules/.../updates/dkms/...`
3. `/sys/bus/i2c/drivers/cs35l41-hda/` 下出现 4 个设备链接
4. `wpctl status` 里有 Speaker sink
5. 试音：
   ```bash
   timeout 5 speaker-test -D hw:0,0 -c 2 -t sine -f 440 -l 1
   ```

如果声音很小或音质一般：Debian/上游没有 `17AA3929` 专用 CS35L41 固件，驱动会回退到通用固件，日志里会有 `Falling back to default firmware`。这是预期行为，不影响出声。以后如果拿到 Windows 驱动里的专用固件，可以放到 `/lib/firmware/cirrus/cs35l41-dsp1-spk-prot-17aa3929.{wmfw,bin}`。

## 内核自动更新（GNOME Software）

- 这台机器没有 `unattended-upgrades`；GNOME Software 会下载更新并提示，安装需要你确认。
- 安装更新时如果包含新内核，DKMS 的 kernel postinst hook 会尝试为新内核自动编译这个模块（`AUTOINSTALL="yes"`）。
- `dkms.conf` 里有限制：
  ```
  BUILD_EXCLUSIVE_KERNEL="^6\.12\."
  ```
  所以：
  - 新的 6.12.x 内核：自动编译；
  - 7.x 内核：不编译（留给内核原生支持；届时请先测试原生是否出声）。
- 更新内核后，建议先选“稍后重启”，确认：
  ```bash
  dkms status
  sudo dkms autoinstall   # 如果新内核还没构建
  ```
  再重启。
- 如果 DKMS 编译失败，**系统仍然正常启动**，只是会用 stock 模块，扬声器可能无声；GRUB 的 Advanced options 可以选回旧内核。
- 不要手动 `apt purge` 6.12.113 内核，否则 `/lib/modules/6.12.113.../updates/dkms` 里的模块也会被删。

## 卸载

```bash
sudo ./uninstall.sh
```

然后重启。它会移除 DKMS 模块、`/usr/src/...` 和 modprobe 配置；不会卸载 `dkms`、头文件或固件。

## 重装系统后

这个目录和 tarball 可以拷到移动硬盘/U 盘。重装后如果还是 Debian 13 + 6.12.x：

```bash
sudo apt install dkms build-essential linux-headers-amd64
sudo ./install.sh
```

如果新系统内核是 7.x：先不要装，直接测试扬声器是否原生可用；不可用再评估是否需要更新补丁。`BUILD_EXCLUSIVE_KERNEL` 会阻止它在 7.x 上自动构建。

## 技术细节

补丁内容（`patch/0001-cs35l41-add-17AA3929.patch`）：

- `cs35l41_config_table[]` 增加：
  ```c
  { "17AA3929", 4, INTERNAL, { CS35L41_RIGHT, CS35L41_LEFT, CS35L41_RIGHT, CS35L41_LEFT }, 0, 2, -1, 1000, 4500, 24 },
  ```
- `cs35l41_prop_model_table[]` 增加：
  ```c
  { "CSC3551", "17AA3929", generic_dsd_config },
  ```

`hda_model=1028:0c4d` 是 6.12 里已有的 Dell 四功放别名（`ALC287_FIXUP_CS35L41_I2C_4` → `cs35l41_fixup_i2c_four`），会创建/绑定 `i2c-CSC3551:00-cs35l41-hda.0~3`。上游 ThinkBook X G2 IAH 补丁作者在同类硬件上就是用这个值测试的。

## 限制与风险

- 只适用于 6.12.x；不是通用补丁。
- 模块由 DKMS 用本机 MOK 密钥自动签名；当前 Secure Boot 关闭。如果以后开启 Secure Boot，需要先把该 MOK 密钥 enroll 到固件里，否则模块无法加载。
- 使用通用 CS35L41 固件，非本机专用调音。
- 这是自编译内核模块，不能像官方内核那样保证；但失效时只会影响声音，不会阻止系统启动。
