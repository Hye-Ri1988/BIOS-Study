---
publish: true
---
# 寄存器查找与配置 + PCH EDS

## 5.1 寄存器查找方法

**在 RU/RW 中查找寄存器的流程：**
1. **确定寄存器类型**：MSR / PCI Configuration Register / IO Port Register
2. **查找寄存器地址**：参考 Intel SDM / PCH EDS，确认 BAR / Offset
3. **在工具中定位**：RU 按 `F5` 选择对应模块，输入地址/偏移量

**寄存器配置流程**

```
查阅文档(PCH EDS/SDM) → 确定寄存器地址
→ RU/RW 中定位 → 读取当前值 → 分析位域含义
→ 修改目标位 → 验证效果
```

**注意事项**
- 修改前务必记录原始值
- 部分寄存器只在特定模式下可写
- 错误的值可能导致系统不稳定
- MSR 访问需要 RDMSR/WRMSR 指令
- 某些位是只读的（Read-Only）
- 参考 PCH EDS 确认位域定义

## 5.2 PCH EDS 是什么

**Platform Controller Hub External Design Specification**
- Intel PCH 的外部设计规格文档
- 包含所有 PCH 寄存器的详细描述
- **BIOS 工程师最重要的参考文档之一**
- 每个 PCH 型号有对应的 EDS 版本

## 5.3 EDS 文档结构

- **Register Descriptions** — 寄存器描述
- **Memory Map** — 内存映射
- **IO Map** — IO 端口映射
- **PCI Configuration** — PCI 配置空间
- **LPC Registers** — LPC 寄存器
- **GPIO Registers** — GPIO 寄存器

## 5.4 PCH EDS 查找流程

```
确定目标功能 → 在 EDS 中搜索关键词 → 定位寄存器描述
→ 确认地址/偏移 → 查看位域定义 → 在 RU/RW 中验证
```

## 5.5 EDS 关键章节与对应 RU 模块

| EDS 章节 | 内容 | 对应 RU 模块 | 常见用途 |
|---------|------|-------------|---------|
| LPC Interface | LPC 寄存器 | ISA | Super I/O, EC, CMOS |
| PCI Configuration | PCI 设备配置 | PCI | 设备枚举, BAR配置 |
| Memory Controller | 内存控制器 | Memory | MTRR, 内存映射 |
| Power Management | 电源管理 | ACPI/MSR | S状态, 功耗控制 |
| GPIO | 通用 IO | Memory Mapped IO | 引脚配置, 中断 |
| SPI Controller | SPI 闪存控制器 | Memory/PCI | BIOS 读写保护 |
| USB Controller | USB 控制器 | PCI | USB 端口配置 |
| Thermal | 热管理 | MSR/ACPI | 温度监控, 风扇控制 |
