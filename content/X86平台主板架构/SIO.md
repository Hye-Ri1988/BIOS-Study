---
publish: true
---
# SIO — Super I/O 控制器

## 概述

集成传统低速 I/O 接口的控制芯片，通过 LPC 总线连接 PCH。厂商：Nuvoton、ITE、Microchip。在现代平台部分功能被 EC 取代，但服务器/工业主板中仍广泛使用。

## 功能

- **串口（COM/UART 16550）**：调试控制台
- **硬件监控（HWM）**：温度/电压/风扇转速
- **PS/2 键鼠接口**（部分保留）
- **LPC TPM 支持**（可信平台模块）

## 配置方式

BIOS 通过 I/O Port 0x2E/0x4E 进入配置模式：选择 Logical Device → 设置 I/O 基址/IRQ → Enable。
