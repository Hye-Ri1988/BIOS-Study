# CMOS 介绍与读写

## 2.1 什么是 CMOS

- **本质**：主板上的可读/写 RAM 芯片，南桥 RTC 模块的组成部分
- **容量**：64~256 字节
- **供电**：纽扣电池供电，断电后数据不丢失
- **位置**：南桥 RTC (Real-Time Clock) 模块 + Clear CMOS 电路

## 2.2 CMOS 的用途

- 保存系统硬件配置信息
- 保存用户 BIOS 设定参数
- 保存系统时间（RTC）
- Clear CMOS 后恢复默认值

## 2.3 CMOS 访问方式

- 通过 ISA 设备访问
- **地址端口**：`0x70` / `0x72`
- **数据端口**：`0x71` / `0x73`
- **Standard bank**：`0x00~0x3F`
- **Extended bank**：`0x40~0xFF`

## 2.4 CMOS Layout（标准 64 字节）

标准 Bank（0x00~0x3F）兼容 MC146818 RTC 芯片布局。

**RTC 时间/日期寄存器（0x00~0x0D）**

| Offset | 名称 | 说明 |
|--------|------|------|
| 0x00 | Seconds | 秒（BCD 或二进制） |
| 0x01 | Second Alarm | 秒闹钟 |
| 0x02 | Minutes | 分 |
| 0x03 | Minute Alarm | 分闹钟 |
| 0x04 | Hours | 时 |
| 0x05 | Hour Alarm | 时闹钟 |
| 0x06 | Day of Week | 星期几（1=周日） |
| 0x07 | Day of Month | 日（1~31） |
| 0x08 | Month | 月（1~12） |
| 0x09 | Year | 年（00~99） |
| 0x0A | Status Register A | UIP/DV/RS 位 |
| 0x0B | Status Register B | SET/PIE/AIE/UIE 等 |
| 0x0C | Status Register C | IRQF/PF/AF/UF 位 |
| 0x0D | Status Register D | VRT 电池有效位 |

**诊断与配置区（0x0E~0x3F）**

| Offset | 名称 | 说明 |
|--------|------|------|
| 0x0E | Diagnostic Status | POST 自检结果 |
| 0x0F | Shutdown Status | 关机/复位状态 |
| 0x10 | Floppy Drive Type | 软驱类型 |
| 0x12 | Hard Disk Type | 硬盘类型 |
| 0x14 | Equipment List | 设备列表 |
| 0x15~0x16 | Base Memory | 常规内存大小 |
| 0x17~0x18 | Extended Memory | 扩展内存大小 |
| 0x19~0x2D | 设备配置 | 硬盘参数、显示模式等 |
| 0x2E~0x2F | Checksum High/Low | CMOS 校验和（0x10~0x2D） |
| 0x30 | Reserved Memory | 保留内存大小 |
| 0x32 | Century (BCD) | 世纪值（BIOS 使用） |
| 0x33~0x3F | 更多配置 | 各种 BIOS 设定参数 |

**Extended Bank（0x40~0xFF，最大 192 字节）**

- 通过 0x72/0x73 端口访问
- 存储高级 BIOS 设定：Boot 顺序、密码、CPU 配置、电源管理等
- 布局取决于 BIOS 厂商和 PCH 型号

> **调试要点**：重点关注 offset 0x0E~0x0F（诊断/复位状态）、0x2E~0x2F（校验和）、RTC 时间区（0x00~0x09）。Clear CMOS 清除所有数据并恢复默认值。

## 2.5 CMOS 读写实践

**通过 RU 工具读取 CMOS**
- 方法一：`RU → F5 → ISA → Port 0x70/0x71`
- 方法二：`RU → F5 → ISA IO → 直接选择 CMOS 模块`

**调试技巧**
- 对比修改前后的 CMOS 值
- Boot 相关设置通常在 Extended CMOS
- RTC 时间区域可直接修改测试
- Clear CMOS 可快速恢复

**实践任务**
1. 搭建 X64 Shell 启动盘
2. 用 `startup.nsh` 自动获取时间并打印至终端
3. 调用 `RU.efi` 学习使用 RU 工具
4. 阅读 EDS 文档，修改 RTC 年月日至 2026.07.03
5. 用 `Screenshot.efi` 截图 BIOS Setup Main 页面的 RTC 时间
