# 安全安装 ClariDiff 1.0.0

ClariDiff 1.0.0 支持 macOS 13 Ventura 或更高版本，同时支持 Apple 芯片和 Intel Mac。

## 校验下载文件

请从同一个 [GitHub Release](https://github.com/qingtan-labs/ClariDiff/releases/tag/v1.0.0) 下载 DMG 与 `SHA256SUMS`，然后运行：

```bash
cd ~/Downloads
shasum -a 256 ClariDiff-1.0.0-Universal.dmg
grep 'ClariDiff-1.0.0-Universal.dmg' SHA256SUMS
```

两行十六进制校验值必须完全相同；如果不同，请删除下载文件。

## 安装应用

1. 打开 `ClariDiff-1.0.0-Universal.dmg`。
2. 将 **ClariDiff** 拖到 **Applications（应用程序）**快捷方式。
3. 在 Finder 中打开“应用程序”。
4. 按住 Control 点击 **ClariDiff**，选择**打开**，再确认一次**打开**。

因为 1.0.0 使用 ad-hoc 签名且尚未经过 Apple 公证，首次运行需要额外确认。请不要全局关闭 Gatekeeper，也不要使用会对所有应用移除隔离属性的命令。

## 安装 CLI

先用 `SHA256SUMS` 校验 CLI，然后运行：

```bash
chmod +x claridiff-1.0.0-macos-universal
sudo install claridiff-1.0.0-macos-universal /usr/local/bin/claridiff
claridiff --version
```

预期输出：`claridiff 1.0.0`。

## 卸载

把“应用程序”中的 `ClariDiff.app` 移到废纸篓。如果安装过 CLI，只删除对应文件：

```bash
sudo rm /usr/local/bin/claridiff
```

ClariDiff 不创建云端账号，也不会在远端保存你的数据副本。
