# PCH — Platform Controller Hub

## 概述

替代传统南北桥架构中的「南桥」功能，通过 DMI（Direct Media Interface）与 CPU 互联。DMI 实质是 PCIe 的变体，带宽约 4GB/s×4 lane。PCH SKU 决定主板功能等级（H/B/Q/Z 系列）。

## 集成的功能模块

- SATA / eSATA 控制器（硬盘接口）
- USB 2.0/3.x 控制器（外设接口）
- High Definition Audio（音频）
- Gigabit Ethernet MAC（网络）
- SPI Controller → 连接 BIOS Flash
- LPC / eSPI → 连接 EC 和 SIO
- SMBus / I2C → 系统管理总线
