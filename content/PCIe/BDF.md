**Bus / Device / Function（BDF）三要素详解**

在 PCI/PCIe 中，**Bus（总线）、Device（设备）、Function（功能）** 是唯一标识配置空间中某个目标的三层寻址体系，即 BDF。之所以需要三层结构，是因为 PCI 引入了 **PCI-to-PCI 桥** 来扩展层次化总线（单条总线因电气负载问题可挂接的设备数量有限）

每个设备（除主机桥外）必须实现配置地址空间；在该空间中，**每个 function（功能）被分配唯一的 256 字节空间**。 因此 BDF 的职责就是：**找到正确的总线 → 找到总线上的设备 → 找到设备内的功能**，然后再加上寄存器偏移即可访问到具体的配置寄存器。

**1. 三个字段的定义与位数**

字段

位数

范围

作用

**Bus Number**

8 bit

0–255（256 条总线）

编码值，用于选择系统中的 1 条总线

**Device Number**

5 bit

0–31（32 个设备）

编码值，用于选择给定总线上的 1 个设备

**Function Number**

3 bit

0–7（8 个功能）

编码值，用于选择多功能设备上的 1 个功能



另外还有一个 **Register Number**（8 bit，按 DWORD 编址），用编码值在目标功能的配置空间中选择一个 DWORD。1_PDF...0.pdf

在配置事务的类型 0/类型 1 地址阶段格式中，`Register Number` 和 `Function Number` 对两种类型意义相同；`Device Number` 和 `Bus Number` 字段仅在类型 1 事务中出现（类型 0 中设备通过 IDSEL 选择，见下文）。1_PDF...0.pdf

**2. Bus Number：层次化总线的"定位符"**

- 支持层次化 PCI 总线需要使用两种配置事务，由 AD[1::0] 区分：**Type 0（AD[1::0] = "00"）** 用于选择**当前运行事务的总线上**的设备；**Type 1（AD[1::0] = "01"）** 用于把配置请求**传递到另一个总线段**。1_PDF...0.pdf
    
- **PCI-to-PCI 桥**解码 Bus Number 字段，判断配置事务的目标总线是否在桥后面：若不在桥后则忽略；若在桥后则认领该事务。1_PDF...0.pdf
    
- 若 Bus Number 匹配桥的 **Secondary Bus Number（次级总线号）**，桥将其转换为 **Type 0** 配置事务，把 AD[1::0] 改为 "00"，其余 AD[10::02] 原样传递；随后 Device Number 被解码以选择本地总线上的 32 个设备之一。1_PDF...0.pdf
    
- 桥通过两个（PCI-to-PCI 桥为三个）寄存器界定层次：**Bus Number 寄存器**指定桥后面第一级总线的编号，**Subordinate Bus Number 寄存器**指定桥后最远层次的总线编号；系统配置软件负责为这些寄存器赋值。1_PDF...0.pdf
    

> 结合上一轮的 I/O 访问：在 CONFIG_ADDRESS（CF8h）中写入 Bus Number 后，主机桥据此判断做 Type 0 转换（Bus Number = 0，直接挂在主机桥下）还是 Type 1 传递（非零，转发给桥），从而最终到达目标总线。

**3. Device Number：通过 IDSEL"片选"设备**

- 配置空间访问要求在**外部完成设备选择解码**，并通过 **IDSEL（Initialization Device Select，初始化设备选择）** 信号通知设备——它充当经典的**片选（chip select）**信号，每个设备有自己独立的 IDSEL 输入。1_PDF...0.pdf
    
- 在 Type 0 配置事务中，桥用 **Device Number 选择要断言的 IDSEL 线**；Function Number 放在 AD[10::08]，Register Number 放在 AD[7::2]，AD[1::0] 必须为 "00"。1_PDF...0.pdf
    
- **IDSEL 的接线方式由系统决定**（系统相关），典型实现是把它连到上部 21 条地址线之一（AD[31::11]，配置访问中未被使用的线）。1_PDF...0.pdf 规范建议的示例映射：Device Number 0 → AD[16]，Device Number 1 → AD[17]……Device Number 15 → AD[31]，这样最多可唯一选中 **21 个设备**；对 Device Numbers 17–31，主机桥应执行事务但不断言任何 AD[31::16] 线，让访问以 **Master-Abort** 终止（读回全 1）。1_PDF...0.pdf
    
- 设备在配置访问中被选中需要：**配置命令被解码 + 自己的 IDSEL 被断言 + AD[1::0] = "00"**（此时 DEVSEL# 被断言来认领事务）。1_PDF...0.pdf
    
- 硬件不规定 Device Number 与 IDSEL 的绑定方式，因此**固件必须扫描全部 32 个设备号**以确保定位所有组件。
    

**4. Function Number：设备内的"子设备"**

对 Type 0 配置周期有响应的设备分为两类，靠配置空间头部的 Header Type 字段区分：1_PDF...0.pdf

**单功能设备（single-function device）**

- 仅为向后兼容而定义，只用 IDSEL 引脚和 AD[1::0] 决定是否响应；1_PDF...0.pdf 可以可选地把所有功能号当作同一个功能响应，或者解码 Function Number 字段（AD[10::08]）只响应功能 0、对其它功能号以 Master-Abort 不响应。1_PDF...0.pdf
    

**多功能设备（multi-function device）**

- 解码 Function Number 字段 AD[10::08]，在 8 个可能功能中选择一个来决定是否响应；1_PDF...0.pdf
    
- 必须对 AD[10::08] 做完整解码，只响应**已实现配置空间寄存器**的功能；未实现的功能号不得响应（Master-Abort 终止）；1_PDF...0.pdf
    
- 必须**始终实现功能 0**，其它功能可选，且可任意编号（例如双功能设备必须响应功能 0，第二功能可以是 1–7 中的任意一个）；1_PDF...0.pdf
    
- 认领事务需同时满足：配置命令被解码、IDSEL 被断言、AD[1::0] = "00"、**AD[10::08] 匹配已实现的功能**。例如实现了功能 0 和功能 4 的设备，会在 IDSEL 断言且 AD[10::08] 为 000 或 100 时断言 DEVSEL#。1_PDF...0.pdf
    

**5. 软件如何利用 BDF 扫描设备**

1. 枚举总线时，配置软件**逐个探测 Device Number**（通常从 0 向上或从 31 向下，顺序未规定）；1_PDF...0.pdf
    
2. 探测到某设备号的功能 0 后，读其 **Header Type 寄存器（偏移 0Eh）的 bit 7**：为 0 表示**单功能设备**，不再检查该设备号的其他功能；为 1 表示**多功能设备**，继续检查所有剩余的功能号；1_PDF...0.pdf
    
3. 选中某个功能后，用 Register Number（AD[7::2]）寻址 DWORD，配合字节使能访问具体寄存器。1_PDF...0.pdf
    

**6. 与上一轮 I/O 访问的衔接**

上一轮讲到 CF8h/CFCh 访问时，CONFIG_ADDRESS 中的位段正好对应 BDF 三层：

`Bit 31 = Enable（1 = 使能） Bits 23–16 = Bus Number ← 第 2 节 Bits 15–11 = Device Number ← 第 3 节 Bits 10–8 = Function Number ← 第 4 节 Bits 7–2 = Register Number（DWORD 偏移）`

1_PDF...0.pdf

例如 `BDF=01:00.0` 即 Bus 1、Device 0、Function 0；要访问其配置空间偏移 4（DWORD 偏移 1），写入 CF8h 的值为 `0x80010004`，再读写 CFCh 即可。PCIe 下这套 BDF 逻辑同样成立，只是底层改用 ECAM（内存映射）生成配置事务，寻址字段不变。

**一句话总结**：**Bus** 把系统划分成最多 256 条层次化总线段（靠桥连接与转发），**Device** 通过 IDSEL 片选在一条总线上挑出最多 32 个物理器件，**Function** 在器件内部挑出最多 8 个独立功能，三者组合（BDF）即可唯一定位任意一个 256 字节配置空间。