# 通用 DEBUG 工具介绍

## 4.1 UEFI Shell 启动盘制作

**制作步骤**
1. 准备 FAT32 格式 U 盘
2. 拷贝 EFI 文件到 `\EFI\BOOT\BOOTX64.EFI`
3. 拷贝调试工具（RU.efi、RW.exe 等）
4. BIOS 设置 U 盘为第一启动项 / 开机按 F7 选择启动设备

**Shell 盘关键文件**

| 文件 | 作用 |
|------|------|
| `BOOTX64.EFI` | 可移动媒体标准文件 |
| `startup.nsh` | 自动执行脚本 |
| `RU.efi` | RU 硬件调试工具 |

**startup.nsh 示例**

```bash
fs0:\EFI\BOOT\RU.efi
```

## 4.2 RU 工具详解

**RU (R-U) = Read-Update**
- UEFI Shell 下运行的硬件调试工具
- 可访问所有 X86 可读写资源：Memory/IO/ISA/PCI/ACPI 等
- BIOS 工程师必备调试工具

**RU 快捷键**

| 快捷键 | 功能 |
|--------|------|
| `F5` | 切换 Device Type |
| `F6` | 选择 PCI Bus/Device/Func |
| `F7` | 数据宽度选择 |
| `F10` / `Alt+Q` | 退出 |
| `Ctrl+I` | System Info |
| `Alt+F2` | E820 Memory Map |

**RU 支持模块**
- PCI / ISA / IO / Memory
- ACPI Tables / CPU MSR / SMBIOS Tables
- SMBUS-SPD/Clock/Byte/Word/Block

**快速参考（所有模式均支持 `F7` 选宽度）**

| 访问类型 | 操作 |
|---|---|
| Memory | `F5` → Memory → 输入物理地址 |
| IO | `F5` → IO Space → 输入端口地址 |
| ISA | `F5` → ISA → 输入 Index/Data 端口 |
| PCI | `F5` → PCI → 输入 Bus/Device/Function |

## 4.3 RW-Everything 工具

- Windows 环境下运行的硬件调试工具，功能与 RU 基本一致
- 图形化界面，无需重启进 Shell，适合快速调试和截图
- 支持模块：Memory、IO Ports、PCI Devices、ACPI、EC、CPU（CPUID/MSR）、SMBIOS

> **提示**：RU 用于 BIOS POST 阶段调试，RW 用于 OS 下快速查看，两者互补。

## 4.4 调试工具集总结

| 工具 | 运行环境 | 主要功能 | 快捷键/命令 | 适用场景 |
|------|---------|---------|------------|---------|
| **RU.efi** | UEFI Shell | 硬件寄存器读写 | F5/F6/F7 | BIOS POST 调试 |
| **RW.exe** | Windows | 硬件寄存器读写 | 图形界面 | OS 下快速调试 |
| **DEBUG.COM** | DOS/实模式 | 汇编调试 | -r -d -e -u -a -t | 底层代码调试 |
| **Helppc** | DOS | 帮助文档 | Alt+Ctrl+T | 查阅硬件资料 |
| **Screenshot.efi** | UEFI Shell | 屏幕截图 | Shift+PrtSc | 问题记录 |

**DEBUG.COM 常用命令**

| 命令 | 功能 |
|------|------|
| `-r` | 查看/修改寄存器 |
| `-d` | 查看内存内容 |
| `-e` | 修改内存数据 |
| `-u` | 反汇编 |
| `-a` | 汇编指令 |
| `-t` | 单步执行 |
| `-g` | 运行到指定地址 |

**Helppc 帮助内容**
- Assembly Grammar（汇编语法）、C Grammar（C 语法）
- Hardware Data（硬件规格）、Interrupt Service（中断服务）、Tables and Formats
