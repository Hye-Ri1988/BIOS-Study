# BIOS/UEFI 知识体系总览

> 这篇笔记把整个学习周期（2026-07-16 至 2026-08-12）的内容串成一条主线：从一块主板怎么工作，到固件怎么把它启动起来，再到固件怎么开发、怎么与操作系统对接、怎么调试排错。各专题的详细内容见文末的分篇索引。

---

## 一、主线：一块主板从通电到进系统的完整链路

整个知识体系可以用一条时间线串起来：

```
硬件平台（CPU/PCH/EC/SIO/内存/PCIe）
    ↓ 固件把硬件"唤醒"
启动流程（SEC → PEI → DXE → BDS → RT）
    ↓ 固件是"怎么构建出来的"
EDK II 构建体系（DSC/FDF/INF/DEC + AMI SDL/eLink）
    ↓ 固件"运行中"的骨架
Boot Services / Runtime Services / 通信机制（PPI/HOB/Protocol/变量）
    ↓ 固件与 OS 的"接口层"
ACPI / SMBIOS / UEFI Shell
    ↓ 底层安全与特殊模式
SMI/SMM、Super I/O
    ↓ 最终手段
调试工具链（RU/RW/Shell/AFU/AMIDEEFI）
```

这条链路的每一环，都对应本仓库的一批笔记。下面按这个顺序把知识串起来。

---

## 二、硬件层：X86 平台主板架构

**核心模型：CPU 直连高速设备 + PCH 桥接低速设备的分层架构。**

- **CPU** 只直连三类最敏感的设备：内存（经内置 IMC，不走 PCH）、独立显卡（PCIe x16，可拆分为 x8+x8）、主 NVMe SSD（PCIe x4）
- **PCH（Platform Controller Hub）** 替代传统南桥，集成 SATA/USB/音频/网络/SPI/LPC 等控制器，通过 DMI（PCIe 变体）与 CPU 互联。设计动机：CPU 引脚数有限，PCH 用极少数引脚换回上千个下游接口
- **EC（嵌入式控制器）**：独立低功耗 MCU（8051/Cortex-M），关机后仍由电池供电运行，负责电源时序、键盘矩阵、风扇、电池管理。开机时序：电源按钮 → EC → 启动电源轨 → 释放 RSMRST → CPU 上电
- **SIO（Super I/O）**：承接传统低速 I/O（串口/PS2/GPIO/硬件监控），经 LPC/eSPI 挂到 PCH 下。笔记本平台部分功能被 EC 取代，台式机/工控/服务器仍是主战场
- **内存**：DDR 在时钟上下沿各传一次数据，速率翻倍；DIMM 插槽提供 64 位数据位宽
- **PCIe**：高速串行点对点总线，Lane 为最小单位，可组合 ×1/×4/×8/×16

**CPU 如何访问外设**（四大地址空间，BIOS 调试的基础）：

| 空间 | 访问方式 | 关键端口/寄存器 |
|---|---|---|
| Memory | 物理地址直接访问 | 段×16+偏移 |
| IO | IN/OUT 指令 | 0x60/0x64（KBC）、0x70/0x71（CMOS/RTC）、0xCF8/0xCFC（PCI） |
| ISA | Index/Data 间接访问 | 0x2E/0x2F（SIO）、0x70/0x71（CMOS） |
| PCI | 配置空间 | CONFIG_ADDRESS（0xCF8）含 Bus/Dev/Func/偏移 |

**寄存器与 CMOS**：寄存器分通用/段/标志/系统寄存器；CMOS 是电池供电的可读写 RAM（标准 64 字节兼容 MC146818 RTC），存 RTC 时间、硬件配置、Setup 参数，通过 0x70/0x71（Index/Data）访问。Clear CMOS 恢复默认值。

> 关联笔记：`X86平台主板架构/`（架构、DDR、PCIe、PCH、EC、SIO、DIMM）、`CMOS、CPU、PCH 知识体系梳理/`（四大空间、CMOS、寄存器、PCH EDS、DEBUG 工具）

---

## 三、启动流程层：UEFI 六大阶段

固件把机器从加电带到能交棒给 OS，走 SEC → PEI → DXE → BDS，之后进入 RT（OS 运行期）/ AL（OS 终止后固件重新接管）。

### SEC（Security）

- 上电后第一段代码，基本只能用汇编
- 建立信任根（烧死在 Flash 受保护区域）、执行 BIST、配置 **Cache-as-RAM（CAR）** 让缓存充当临时内存
- 从实模式切到保护模式
- Reset Vector 在 0xFFFFFFF0，SEC 代码放 Flash 顶端

### PEI（Pre-EFI Initialization）

- 分两段：**Pre-Mem**（CAR 环境，芯片组早期初始化、**MRC 内存训练**——启动中最耗时步骤）→ **Post-Mem**（PEI 从 CAR 复制到 DRAM 重跑，硅初始化）
- 创建 **HOB 列表**（资源清单）→ 触发 `EfiEndOfPeiSignal` → 调 **DXE IPL PPI** 进 DXE
- PEI 最小代码层：Recovery 用、S3 要求路径最短
- 特殊启动路径：Normal / BIOS Recovery / ACPI S3 Resume

### DXE（Driver Execution Environment）

- 代码量最大。DXE Foundation 先建运行环境：解析 HOB、初始化内存/Handle/Image/GCD 服务、创建 EFI System Table
- Dispatcher 扫描 Firmware Volume，按 **Depex** 依赖表达式调度驱动
- 成果：架构协议就绪、PCI 枚举、设备初始化、ACPI/SMBIOS 表创建、`EndOfDxe` 信号锁定安全边界

### BDS（Boot Device Selection）

- 属于 DXE 阶段内部环节（经 EFI_BDS_ARCH_PROTOCOL 调 BdsEntry）
- 三件事：连接设备、管理启动选项、加载 OS
- 从 NVRAM 读 BootOrder/BootXXXX → 枚举匹配 → 按优先级启动 → LoadImage+StartImage 加载 OS Loader
- AMI 平台由 **BdsControlFlowFunctions[]** 函数指针数组（eLink 注入）驱动

### 阶段间通信机制

| 机制 | 阶段 | 本质 |
|---|---|---|
| **PPI** | PEI 内 | PEIM-to-PEIM 接口，带 GUID 的函数指针表，PEI 结束释放 |
| **HOB** | PEI → DXE | 连续内存中的握手块，PEI 写、DXE 只读（唯一传话机制，因为两阶段内存空间不同） |
| **Protocol** | DXE 内 | Handle 数据库上的接口，gBS 安装/定位 |
| **变量** | 全周期 | NVRAM 持久化，Boot/Runtime 均可访问 |

> 关联笔记：`EFI Framework Overview/`、`SEC & PEI/`（含 PPI 跨 PEIM 通信）、`PEI HOB/`、`DXE/`、`BDS/`

---

## 四、构建体系层：EDK II 与 AMI Aptio V

### EDK II 四类元数据文件

| 文件 | 职责 | 一句话 |
|---|---|---|
| **DSC** | 平台描述 | What & How：构建哪些模块、库类映射、PCD 取值 |
| **FDF** | Flash 描述 | Where & Layout：模块摆进哪个 FV、是否压缩 |
| **INF** | 模块信息 | 单个模块的配方：源码、依赖、GUID、入口 |
| **DEC** | 包声明 | 包提供什么：GUID/Protocol/Library/PCD 声明 |

核心关系：**DSC 引用 INF 确定构建哪些模块 → INF 引用 DEC 查找定义 → FDF 决定布局 → BaseTools 生成 FV/FD**。

关键概念：
- **MODULE_TYPE**：PEIM / DXE_DRIVER / DXE_SMM_DRIVER / UEFI_DRIVER / LIBRARY，决定入口库（PeimEntryPoint / UefiDriverEntryPoint / UefiApplicationEntryPoint）
- **库类 vs 库实例**：库类=接口（.h 声明），库实例=实现（.c+.inf），DSC 映射"选一个"——同一套接口不同阶段挂不同实现（PEI 轻量版、DXE 完整版）
- **PCD（平台配置数据库）**：FeatureFlag（编译开关）/ FixedAtBuild（编译定死）/ PatchableInModule（可补丁）/ Dynamic（运行时可变）
- **Depex**：依赖表达式，决定调度顺序（TRUE 无条件、GUID 依赖、AND/OR 组合）

### AMI Aptio V 扩展层：SDL / eLink / eModule

- **SDL（Source Description Language）**：AMI 的平台描述语言，"一份数据、多种输出"。AMISDL 工具自动生成 DSC/FDF/ASL
  - INFComponent（模块声明）→ DSC [Components]
  - LibraryMapping（库类→实例映射）→ DSC [LibraryClasses]，优先级 Override > Module_Type > Arch > 全局
  - PCDMapping / Token → DSC [Pcds*]
  - FD_INFO/FD_AREA/FFS_FILE → FDF
- **eLink 扩展机制**：模块间可扩展链接。Parent eLink 是扩展点，Child eLink 注册功能函数，构建时自动合并成函数表（如 BDS_CONTROL_FLOW、TSE Hook）
- **eModule 创建**：四类核心文件 SDL（FFS_FILE）+ CIF（组件信息）+ INF + DEC；工程级还要改包 .cif（注册子模块）、.dec（[Includes] + [Guids]/[Protocols] 定义）

### 库实例解析优先级（EDK II 官方）

组件级作用域 > [LibraryClasses.Arch.ModuleType] > [common.ModuleType] > [Arch] > [LibraryClasses] 全局。SDL 的优先级是它的翻版。

> 关联笔记：`EDK2 DSC & FDF/`、`INF & DEC文件详解/`、`Library Mapping/`、`Aptio V eModule_oem & Elink/`

---

## 五、服务层：Boot Services 与 Runtime Services

### Boot Services（gBS，ExitBootServices 前有效）

- **来源**：SystemTable->BootServices，UefiBootServicesTableLib 缓存为 gBS
- 服务类别：Task Priority（TPL）、Memory（Pages/Pool）、Event & Timer、Protocol Handler、Image、Driver Support、Misc
- 关键点：
  - **TPL**（任务优先级）：APPLICATION < CALLBACK < NOTIFY < HIGH_LEVEL，Raise/Restore 必须成对同函数
  - **内存**：Pages 以 4KB 为单位，Pool 适合小块；EfiBootServicesData（OS 回收）vs EfiRuntimeServicesData（需保留）
  - **事件**：无硬件 IRQ，一切异步基于 Event；SetTimer 时间单位 100ns；CreateEventEx 支持事件组
  - **协议**：Install/Locate/Open/Close；OpenProtocol 优于 HandleProtocol（带引用追踪）
  - **镜像**：LoadImage 不执行，StartImage 才跳入口
  - **ExitBootServices**：分水岭，调用前必须取最新 memory map 并重试循环

### Runtime Services（gRT，ExitBootServices 后仍可用）

- 14 个函数指针分五类：Variable / Time / Virtual Memory / Reset / Capsule（+Misc）
- **变量服务**（最重要）：(Name, VendorGuid) 二元组标识；属性 NV/BS/RT 组合；GetVariable 两次调用范式（先探大小）；NVRAM 只有几十~几百 KB，写满触发 reclaim（高危路径）；量产平台经 SMM 实现（VariableSmmRuntimeDxe + VariableSmm）
- **虚拟地址映射**：OS 调 SetVirtualAddressMap 后固件重定位 runtime 镜像；驱动内部指针要自己经 ConvertPointer 转（先叶子后根），漏转一个就是内核崩溃
- **复位**：ResetSystem 不返回；冷复位 0x0E / 热复位 0x06（PCH 0xCF9）；封装 ResetSystemLib 可在 PEI 用
- **Capsule**：固件在线升级，内存投递 or Capsule on Disk，ESRT 暴露可升级资源
- **Runtime 驱动约束**：MODULE_TYPE=DXE_RUNTIME_DRIVER、[Depex] 强制、资源必须 ExitBootServices 前分配、处理两个事件（ExitBootServices/VirtualAddressChange）

> 关联笔记：`Boot Services/`、`RunTime Services/`

---

## 六、接口层：ACPI 与 SMBIOS

### ACPI（固件 ↔ OS 的"硬件操作手册"）

- **核心理念 OSPM**：OS 主导电源管理，固件提供数据和方法
- 两部分：**表**（静态描述硬件）+ **控制方法**（AML 字节码，OS 解释执行）
- 表发现链路：RSDP → XSDT → FADT → DSDT/SSDT。UEFI 下 OS 从 EFI Configuration Table 拿 RSDP（不扫内存）
- 命名空间：_SB/_PR/_TZ/_GPE 四大根节点；对象名 4 字符，下划线开头是规范保留名
- 电源状态：G/S/D/C-P-T 四级；S3 只保内存供电，唤醒矢量写 FACS
- **SCI vs SMI**：SCI 由 OS 的 ACPI 驱动处理（OS 可见）；SMI 进 SMM 由固件处理（OS 不可见）
- 资源分配：_PRS 探测 → OS 仲裁 → _SRS 写回 → _CRS 验证
- 调试：acpidump + iasl -d（反汇编）、RW/HE、acpiexec

### SMBIOS（"系统身份证"）

- 静态快照：POST 时构建，运行期不更新；描述"系统是什么"（型号/SN/插槽），与 ACPI 的"系统如何工作"互补
- 定位：UEFI 下经 Configuration Table 的 SMBIOS_TABLE_GUID / SMBIOS3_TABLE_GUID（禁止扫 0xF0000 段）
- Structure 布局：4 字节 Header（Type/Length/Handle）+ 格式化区 + String-Set（索引从 1 起，双空结束）
- 常用 Type：0 BIOS / 1 System（SN、UUID ★）/ 2 Baseboard（主板 SN ★）/ 3 Chassis / 4 Processor / 7 Cache / 16+17 内存（Handle 关联）
- **EFI_SMBIOS_PROTOCOL 四接口**：Add / GetNext / UpdateString（只改字符串，UUID 要 Remove+Add）/ Remove
- **AMIDEEFI**：产线写 SN/UUID 的工具，数据持久化到 SPI Flash NVRAM/DMI 区，重启后重建

> 关联笔记：`ACPI/`、`SMBIOS/`

---

## 七、底层机制层：SMI/SMM 与 Super I/O

### SMI/SMM（Ring -2）

- **SMI**：特权级最高的不可屏蔽中断；**SMM**：对 OS 完全透明的 CPU 模式；**SMRAM**：专用内存区，非 SMM 不可访问
- 链路：SMI 信号 → CPU 存上下文到 Save State → 跳 SMBASE+0x8000 → Handler 分发 → RSM 退出
- 触发：硬件（系统事件/RTC/GPIO/IO Trap/SMI# Pin）或软件（写 0xB2 APM 端口，走 SmmControl2.Trigger()）
- SMBASE 默认 0x30000 全核相同，POST 中重定位到 TSEG 内不同地址
- **SMM Communication**：DXE/OS → SMM 的唯一 IPC。CommBuffer + 触发软件 SMI + SmiManage 分发。安全关键：Handler 必须校验 CommBuffer（SmmIsBufferOutsideSmmValid）
- 用途：Flash 写保护、Legacy USB、ACPI 电源切换、硬件错误记录——"OS 看不见的硬件操作"
- 实战（OemSmi）：DXE_SMM_DRIVER 双半身架构，DXE 半身读 Setup 变量，SMM 半身在 Sx/电源键 SMI 时操作 IT8786 GPIO（LED/AC 策略）和 PM1（WOL）

### Super I/O（SIO）

- 承接串口/PS2/GPIO/硬件监控，经 LPC/eSPI 挂 PCH
- **访问模型**：Index/Data 端口（0x2E/0x2F）+ LDN（逻辑设备号，Index 0x07 选择）+ 解锁口令（0x2E 口 87 01 55 55）
- 配置流程：解锁 → 选 LDN → 配基址/IRQ/Activate(0x30) → 锁回
- 子系统：UART（16C550，COM1=0x3F8）、KBC（0x60/0x64）、GPIO（复用选择→使能→方向→数据）、EC/HWM（温度 TMPIN/电压 VIN/风扇 SmartGuardian）
- **表驱动初始化**：AMI 用 IO_TABLE_ENTRY {Port, AndMask, OrValue} 三元组数组，遍历执行
- 与 MCU 类比：GPIO 配置流程（复用+方向+数据）与 STM32 完全同构，只是寄存器藏在 Index/Data 后要先解锁

> 关联笔记：`SMI/`、`Super IO/`（含 GP40 实践排错：FSP 方案工程别引 AMI 库链）

---

## 八、调试层：工具链全貌

| 工具 | 环境 | 用途 |
|---|---|---|
| **RU.efi** | UEFI Shell | 硬件寄存器读写（F5 切类型/F6 选 PCI/F7 宽度），POST 阶段调试 |
| **RW.exe** | Windows | 同 RU，图形界面，OS 下快速查看（注意 SIO 视图 vs IO Space 视图） |
| **UEFI Shell** | 预启动 | pci / memmap / mm / dh / devices / dmpstore / setvar / bcfg / smbiosview |
| **startup.nsh** | Shell | 自动执行脚本，批量导出调试信息 |
| **AFU** | DOS/EFI/Win/Linux | 固件烧录（/P 主区、/B Boot Block 高风险、/N 清 NVRAM、/CAPSULE） |
| **AMISCE** | Shell | 读写 Setup 变量，不进 Setup 改设置 |
| **MMTool** | Windows | 固件模块管理（提取/替换 FFS、微码、Option ROM） |
| **AMIDEEFI** | Shell | 读写 SMBIOS（产线写 SN/UUID） |
| **UEFITool** | Windows | ROM 结构拆解（FV/FFS/Section/压缩） |
| **串口日志** | 硬件 | 按关键标识断句：CAR Init → PeiCore.Entry → MRC → EndOfPei → DXE-Core.Entry → EndOfDxe → HandoffToTse |

**调试心法**：所有硬件访问都逃不出四大空间（Memory/IO/ISA/PCI）+ 两个表（ACPI/SMBIOS）。遇到问题先定位"它在哪个空间、哪个阶段、哪个表"。

> 关联笔记：`UEFI shell调试命令和APP/`、`CMOS、CPU、PCH 知识体系梳理/通用 DEBUG 工具介绍.md`、`EFI Framework Overview/实践记录.md`（日志断句）、`BIOS 编译环境搭建/`、`Git 使用/`

---

## 九、贯穿全周期的关键认知

1. **分层与解耦无处不在**：硬件分层（CPU/PCH）、启动阶段分层（SEC→BDS）、构建分层（SDL→DSC/FDF→EDK II）、通信解耦（PPI/Protocol/HOB/变量各有生命周期）
2. **"接口不变、实现可换"是 EDK II 的灵魂**：库类映射（DebugLib 空实现/串口实现）、Protocol 函数指针表、eLink 扩展点，本质都是依赖注入
3. **阶段边界就是通信机制切换点**：PEI 用 PPI，PEI→DXE 用 HOB，DXE 用 Protocol，进 OS 用 Runtime Services——记清每个机制的生命周期
4. **两套"固件↔OS 的对话"**：ACPI（可执行的方法）+ SMBIOS（静态描述），一个管怎么工作，一个管是什么
5. **安全边界**：EndOfDxe 锁 DXE、SMM 锁 Flash、RT 只留受控接口——固件的每一步都守着一条信任边界

---

## 分篇索引

| 主题 | 目录 |
|---|---|
| 硬件架构 | `X86平台主板架构/` |
| 寄存器/CMOS/调试工具 | `CMOS、CPU、PCH 知识体系梳理/` |
| 启动六阶段 | `EFI Framework Overview/` |
| SEC/PEI/PPI | `SEC & PEI/` |
| PEI→DXE 传话 | `PEI HOB/` |
| DXE/Protocol | `DXE/` |
| 启动选择 | `BDS/` |
| 启动期服务 | `Boot Services/` |
| 运行期服务 | `RunTime Services/` |
| EDK II 构建 | `EDK2 DSC & FDF/`、`INF & DEC文件详解/` |
| AMI 扩展 | `Aptio V eModule_oem & Elink/`、`Library Mapping/`、`Hook_List/` |
| OS 接口 | `ACPI/`、`SMBIOS/` |
| 底层模式 | `SMI/`、`Super IO/` |
| 调试 | `UEFI shell调试命令和APP/` |
| 工具链 | `BIOS 编译环境搭建/`、`Git 使用/` |
