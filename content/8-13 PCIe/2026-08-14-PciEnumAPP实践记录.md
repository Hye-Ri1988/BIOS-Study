---
publish: true
---


## 一、解析步骤

| 分组 | 函数 | 职责 |
|---|---|---|
| 入口与分发 | PciEnumAPPMain | 读 LoadOptions、解析参数、分派两条路径 |
| 字符工具 | IsHexChar / HexCharValue / CharEqIgnoreCase / HasDumpFlag | 十六进制换算、大小写无关比较、-dump 标志扫描 |
| 名称映射 | GetClassName / GetPortTypeName / GetLinkSpeedName / GetLinkWidthName / GetCapName / GetEcapName | 寄存器值 → 可读名称 |
| 字节访问 | DwordAt / WordAt / ByteAt | 从 UINT32 dump 按字节偏移取值 |
| PCIe 判定 | IsPcieRootPort | 遍历 Cap 链表判定 Root Port |
| 报告输出 | PrintBar / PrintCapabilities / PrintExtendedCapabilities / PrintDeviceReport | 单设备详细报告 |
| 数据通路 | ReadConfig4K / WriteDumpFile / EnumerateAllDevices | 4K 读取、落盘、全量枚举 |

分组依据：调用方向单一，工具层（字符/名称/字节）只被上层引用，无反向依赖。

运行路径确认

入口按是否解析出 Bus 参数分派：

- 无 Bus → `EnumerateAllDevices`（全量枚举）
- 有 Bus 且 Dev/Func 齐全 → 单设备报告
- 有 Bus 但缺 Dev/Func → Usage 提示，返回 `EFI_INVALID_PARAMETER`

### 步骤 4：关键代码函数实现

## 二、关键实现部分

### 1. PciEnumAPPMain —— 入口与参数分发

作用：从 `LoadedImage->LoadOptions` 取 Shell 传入参数，手写扫描器解析，按参数分派。

实现要点：

- `HandleProtocol(ImageHandle, &gEfiLoadedImageProtocolGuid)` 拿 LoadOptions；`LoadOptionsSize == 0` 时打印空参数提示
- 参数扫描：逐 token 累积十六进制值 `V = (V << 4) + HexCharValue(c)`；`:` 与 `.` 作为分隔符跳过；非 hex token（如 `-dump`）整体跳过；最多收 3 个值，依次落到 Bus/Dev/Func
- `HasDumpFlag` 独立扫描 `-dump`
- 单设备流程：`LocateHandleBuffer(PciIo)` → 按 BDF 比对句柄 → `AllocatePool(0x1000)` → `ReadConfig4K` → `PrintDeviceReport` → 可选 `WriteDumpFile` → `FreePool`

结论：参数刻意兼容 `PciEnumAPP 0 6 0`（空格）与 `PciEnumAPP 0:6.0`（冒号点）两种写法——Shell 交互下 BDF 惯例用冒号点，脚本调用常空格分隔。

### 2. EnumerateAllDevices —— 全量枚举

作用：列出系统全部 PCIe 设备。

实现要点：

- `LocateHandleBuffer(ByProtocol, &gEfiPciIoProtocolGuid, ...)` 拿全部 PCI 设备句柄，只覆盖 DXE 驱动已实例化 PciIo 的设备
- `PciIo->GetLocation` 取 BDF（Segment 被丢弃，见局限）
- 读 0x00（VID:DID）、0x08（Class:Rev）；VID == 0xFFFF 跳过
- Class == 06/04（P2P Bridge）时调 `IsPcieRootPort`，命中追加 `[ROOT PORT]` 标记
- 统计 DeviceCount / RootPortCount，输出汇总行

### 3. IsPcieRootPort —— Root Port 判定

作用：判断 P2P Bridge 设备是否为 PCIe Root Port。

实现要点：

- 读 0x34 取能力链表头 CapPtr
- 沿链表遍历，`Depth < 32` 防死循环，`Next == CapPtr` 防环：
  - `CapId == 0x10`（PCIe Cap）→ 读 CapPtr+2 的 Capabilities Register
  - `PortType = (PcieCap >> 4) & 0x0F`，等于 0x04 即 Root Port
- 非 PCIe Cap 时读 CapPtr+1 的 Next 指针继续

结论：Root Port 判定纯配置空间推导，不依赖 ACPI 或设备树，与固件无关——这是实测 3 个 Root Port 精确识别的原因。


### 4. PrintDeviceReport —— 单设备报告主函数

作用：把 4K dump 解析为可读报告。

输出内容：

- VID:DID / Rev / Class（0x0B、0x0A、0x09）/ HeaderType（0x0E）
- Type1（Bridge，`HeaderType & 0x7F == 0x01`）：Primary/Secondary/Subordinate 总线号（0x18/0x19/0x1A）、IO/Mem/Prefetch 窗口
- Type0：6 个 BAR 循环打印 + Subsystem VID:DID（0x2C）
- IntLine/IntPin（0x3C/0x3D）
- `PrintCapabilities` + `PrintExtendedCapabilities`
- 原始 0x00-0x3F 头部 hex dump，16 字节/行

### 5. PrintBar —— BAR 解析

作用：解析单个 BAR，返回其占用的槽位数。

实现要点（按位域分支）：

- 从 0x10 + BarIndex*4 读 BAR 值；等于 0 → disabled
- BIT0 == 1 → IO BAR，地址 `& ~0x3`，返回 1
- `Type = (Bar >> 1) & 0x3`；等于 0x2 → Mem64：高 32 位从下一槽（0x14 + BarIndex*4）取，地址 `& ~0xF`，返回 2
- 其余为 Mem32，返回 1

调用处 `Index += PrintBar(Dump, Index)` 靠返回值跳过 Mem64 高半槽——这是 Type0 六槽遍历正确性的关键：若固定 +1，Mem64 的高 32 位会被误报成独立 BAR。

### 6. ReadConfig4K —— 4K 配置空间读取

作用：逐 DWORD 读满 0x1000。

要点：

- 0x100 ~ 0xFFF 属 ECAM/MCFG 扩展区，传统 256B config 窗口不可达；任一偏移读失败即整体失败
- 失败路径释放 Dump 缓冲后返回，上层打印 ECAM/MCFG 缺失提示，不产生脏数据报告

### 7. PrintCapabilities / PrintExtendedCapabilities

PrintCapabilities：

- 从 0x34 链表遍历，打印每个 CapID 及名称
- PCIe Cap 额外解析：LinkCap（+0x0C，MaxSpeed = 低 4 位，MaxWidth = bit4-9）、LinkStatus（+0x12，协商速率/宽度）——直接读出设备支持档位与当前协商档位

PrintExtendedCapabilities：

- 从 0x100 起按扩展能力头 bit20-31（Next Pointer，单位 4B）遍历
- 终止条件：NextOffset == 0 或 `NextOffset + 0x100 <= Offset`（防环）
- EcapID == 0x0001（AER）时打印 Uncorrectable Status（+0x04）/ Correctable Status（+0x10）

### 8. WriteDumpFile —— -dump 落盘

- `LocateHandleBuffer(SimpleFileSystem)` → `OpenVolume` → `Root->Open(文件名, READ|WRITE|CREATE)` → `Write(0x1000)`
- 文件名 `pcie_%02x%02x%02x.bin`（BDF 直接拼 hex）
- 遍历全部文件系统句柄，首个写入成功即停；无 SimpleFileSystem 时警告并返回 `EFI_NOT_FOUND`

### 9. 工具层

- DwordAt/WordAt/ByteAt：`Dump[Offset >> 2] >> ((Offset & 3) * 8)`，小端字节序假设，x86 成立
- IsHexChar/HexCharValue/CharEqIgnoreCase：hex 判定与换算、大小写无关比较
- HasDumpFlag：按空白分词扫描参数串，匹配 `-dump`（忽略大小写）
- 名称映射 6 函数：查表式，覆盖 8 类设备（Host Bridge/P2P/NVMe/SATA/Ethernet/VGA/xHCI/HD Audio）、9 种 PCIe 端口类型、5 档速率、6 档宽度、13 个 CapID、19 个 EcapID

## 三、运行方式

```
PciEnumAPP                  # 全量枚举
PciEnumAPP 0 6 0            # 空格格式
PciEnumAPP 0:6.0            # 冒号点格式
PciEnumAPP 0:6.0 -dump      # 报告 + 原始 4K 落盘 pcie_000600.bin
```

