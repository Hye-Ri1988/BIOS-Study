---
publish: true
---
# PPI 跨 PEIM 通信

从一个具体例子开始：两个 PEIM 在 PEI 阶段协作——一个提供 CMOS 读写功能，另一个用它读 RTC 时间校验。PPI 就是干这个用的。

## 前置概念

PPI 全称 PEIM-to-PEIM Interface，只在 PEI 阶段存在，整个 PPI 数据库在 PEI 阶段结束后释放。本质是一个带 GUID 的函数指针表。

和 DXE 阶段 Protocol 的区别：PPI 没有 Handle、没有 Open/Close，比 Protocol 简单。PPI 存在 PEI 数据库里，通过 PeiServices 表操作。PEIM 之间通过 PPI 通信是松耦合的——生产者和消费者的 INF 各自独立，唯一共享的是一份头文件和一个 GUID。

## 整体流程

生产者 PEIM 先执行，把 PPI 装进 PEI 数据库。消费者 PEIM 通过 Depex 声明依赖，PEI 调度器自动保证"生产者跑完才跑消费者"。

```
CmosPpi.h          ← 两个 PEIM 共同引用的头文件（GUID + 接口定义）
     │
     ├── CmosPpi.c / CmosPpi.inf         ← 生产者：InstallPpi
     │
     └── MyPeiM.c / MyPeiM.inf（修改）   ← 消费者：LocatePpi → 调用
```

## 文件清单和创建顺序

### 1. CmosPpi.h — 共享头文件

PPI 的规范声明，生产者和消费者都 include，保证双方看到的 GUID 和函数签名完全一致。

```c
#ifndef __JYTIAN_CMOS_PPI_H__
#define __JYTIAN_CMOS_PPI_H__

#define JYTIAN_CMOS_PPI_GUID \
  { \
    0x9A5B6C7D, 0x8E7F, 0x6D5C, \
    { 0x4B, 0x3A, 0x2C, 0x1D, 0x0E, 0xFF, 0xEE, 0xDD } \
  }

extern EFI_GUID  gJYTianCmosPpiGuid;

#define JYTIAN_CMOS_PPI_REVISION  0x00010000

typedef struct _JYTIAN_CMOS_PPI {
  UINTN       Revision;
  EFI_STATUS  (EFIAPI *ReadCmos) (IN UINT8 Address, OUT UINT8 *Value);
  EFI_STATUS  (EFIAPI *WriteCmos)(IN UINT8 Address, IN  UINT8 Value);
} JYTIAN_CMOS_PPI;

#endif
```

要点：
- 没有头文件的话，生产者和消费者各自写结构体，函数签名对不齐编译不报错，运行时调用直接崩
- GUID 用 VS 的 `guidgen.exe` 生成，不要手写
- GUID 的 extern 声明放头文件，实际定义只写在生产者 .c 里（头文件里带 `=` 赋值，每个 include 的 .c 都生成一份，链接报重复定义）
- 结构体第一个字段固定为 Revision，方便以后加新函数指针时兼容旧版本

### 2. CmosPpi.c — 生产者实现

只做两件事：实现头文件里声明的函数，然后在入口点 InstallPpi。

```c
#include <PiPei.h>
#include <Library/DebugLib.h>
#include <Library/IoLib.h>
#include <Library/PeiServicesLib.h>
#include "CmosPpi.h"

EFI_GUID  gJYTianCmosPpiGuid = JYTIAN_CMOS_PPI_GUID;

EFI_STATUS
EFIAPI
CmosRead (
  IN  UINT8  Address,
  OUT UINT8  *Value
  )
{
  if (Value == NULL) {
    return EFI_INVALID_PARAMETER;
  }
  IoWrite8 (0x70, Address);
  *Value = IoRead8 (0x71);
  return EFI_SUCCESS;
}

EFI_STATUS
EFIAPI
CmosWrite (
  IN UINT8  Address,
  IN UINT8  Value
  )
{
  IoWrite8 (0x70, Address);
  IoWrite8 (0x71, Value);
  return EFI_SUCCESS;
}

JYTIAN_CMOS_PPI  gJYTianCmosPpi = {
  JYTIAN_CMOS_PPI_REVISION,
  CmosRead,
  CmosWrite
};

EFI_PEI_PPI_DESCRIPTOR  gCmosPpiDesc = {
  EFI_PEI_PPI_DESCRIPTOR_PPI | EFI_PEI_PPI_DESCRIPTOR_TERMINATE_LIST,
  &gJYTianCmosPpiGuid,
  &gJYTianCmosPpi
};

EFI_STATUS
EFIAPI
CmosPpiEntryPoint (
  IN       EFI_PEI_FILE_HANDLE  FileHandle,
  IN CONST EFI_PEI_SERVICES     **PeiServices
  )
{
  EFI_STATUS  Status;
  Status = PeiServicesInstallPpi (&gCmosPpiDesc);
  DEBUG ((DEBUG_INFO, "[CmosPpi] InstallPpi Status = %r\n", Status));
  return Status;
}
```

要点：
- CMOS 读写通过 IO 端口 0x70（写地址）和 0x71（读/写数据），用 IoLib 的 IoWrite8/IoRead8
- 安装 PPI 用 PeiServicesLib 的 `PeiServicesInstallPpi()` 封装，比直接用 `PeiServices->InstallPpi` 少传参数
- Descriptor 的 Flags 里 `TERMINATE_LIST` 不能漏，漏了 PEI 核心会顺着 PPI 链表读到野指针

### 3. CmosPpi.inf — 生产者 build 描述

```inf
[Defines]
    INF_VERSION                    = 0x00010005
    BASE_NAME                      = CmosPpi
    FILE_GUID                      = 9B8C7D6E-5F4A-3E2D-1C0B-9A8F7E6D5C4B
    MODULE_TYPE                    = PEIM
    VERSION_STRING                 = 1.0
    ENTRY_POINT                    = CmosPpiEntryPoint

[Sources]
    CmosPpi.c

[Packages]
    MdePkg/MdePkg.dec

[LibraryClasses]
    PeimEntryPoint
    DebugLib
    IoLib
    PeiServicesLib

[Depex]
    TRUE
```

MODULE_TYPE 填 PEIM（不是 BASE），因为模块有入口点，需要被 PEI 调度器执行。ENTRY_POINT 必须和 .c 里的函数名完全一致。Depex 填 TRUE 表示无依赖——生产者总是应该最先跑的。

### 4. JYTianPpiModule.cif — 模块注册

```xml
<component>
    name = "JYTianPpiModule"
    category = ModulePart
    LocalRoot = "OemJYTianPkg/JYTianPpiModule/"
    RefName = "JYTianPpiModule"
[INF]
"CmosPpi.inf"
[files]
"JYTianPpiModule.sdl"
<endcomponent>
```

AMI 的 build 系统通过 .cif 文件发现模块。模块目录下必须有 .cif，否则系统不知道这里有 INF 要编译。

### 5. JYTianPpiModule.sdl — SDL 配置

```sdl
TOKEN
    Name  = "JYTianPpiModule_SUPPORT"
    Value  = "1"
    Help  = "Enable JYTianPpiModule support"
    TokenType = Boolean
    TargetMAK = Yes
    Master = Yes
End

TOKEN
    Name  = "CmosPpi_INF_SUPPORT"
    Value  = "1"
    Help  = "Enable CmosPpi support"
    TokenType = Boolean
End

INFComponent
    Name  = "CmosPpi"
    File  = "CmosPpi.inf"
    Package  = "OemJYTianPkg"
    ModuleTypes  = "PEIM"
    Token = "CmosPpi_INF_SUPPORT" "=" "1"
End
```

最容易出错的三处：
- **Package 是必填字段**，缺了 SDL 处理器直接报 `Mandatory object missing - Package`
- **ModuleTypes 决定模块放进哪个 FV**。PEIM 填 PEIM，DXE_DRIVER 填 DXE_DRIVER
- **Name、File、Token 三个名字要对齐**——File 必须和目录里实际的 .inf 文件名一致

### 6. OemJYTianPkg.cif — 包级注册（改已有文件）

在 parts 段末尾加一行 `"JYTianPpiModule"`。不加这行，SDL 处理时不会加载 JYTianPpiModule 的 .cif，整个模块不会编译打进 FV。

### 7. OemJYTianPkg.dec — GUID 定义（改已有文件）

两个位置要改：
- **Includes 段**加一行 `JYTianPpiModule`，让其他模块能 include 到头文件
- **新增 [Guids] 段**定义 PPI GUID 的值：

```
[Guids]
  gJYTianCmosPpiGuid = { 0x9A5B6C7D, 0x8E7F, 0x6D5C, { 0x4B, 0x3A, 0x2C, 0x1D, 0x0E, 0xFF, 0xEE, 0xDD } }
```

消费者 Depex 里写了 gJYTianCmosPpiGuid，build 系统需要从包的 .dec 里查到它的 16 字节值才能生成依赖表达式。不定义的话 build 阶段报 `Value of gJYTianCmosPpiGuid is not found`。

### 8. 修改消费者 PEIM（MyPeiM.c + MyPeiM.inf）

**MyPeiM.c** 加三样：include 头文件、include PeiServicesLib、在入口函数末尾 LocatePpi 并调用。

```c
#include <CmosPpi.h>
#include <Library/PeiServicesLib.h>

EFI_STATUS
EFIAPI
MyPeiEntryPoint(...)
{
  EFI_STATUS       Status;
  JYTIAN_CMOS_PPI  *CmosPpi;
  UINT8            CmosValue;

  // ... 原有代码不变 ...

  Status = PeiServicesLocatePpi (
             &gJYTianCmosPpiGuid,  // 按 GUID 查找
             0,                     // Instance，0 表示找第一个
             NULL,                  // 不需要 descriptor
             (VOID **)&CmosPpi      // 拿到 PPI 指针
             );
  if (!EFI_ERROR (Status)) {
    CmosPpi->ReadCmos (0x0E, &CmosValue);
    DEBUG ((DEBUG_INFO, "CMOS[0x0E] = 0x%02x\n", CmosValue));
  }

  return EFI_SUCCESS;
}
```

LocatePpi 拿到的是空指针，要转成具体的 PPI 结构体类型才能用 `->` 调函数指针。

**MyPeiM.inf** 三处改动：

```diff
 [LibraryClasses]
+  PeiServicesLib

+[Guids]
+  gJYTianCmosPpiGuid

 [Depex]
-  TRUE
+  gJYTianCmosPpiGuid
```

- PeiServicesLib 提供 PeiServicesLocatePpi()，不加链接报 undefined
- [Guids] 告诉 build 系统"这个模块用到了这个 GUID"
- Depex 从 TRUE 改成 gJYTianCmosPpiGuid 是核心：生产者没装好 PPI 之前别执行我。维持 TRUE 的话消费者可能在生产者之前执行，LocatePpi 返回 NOT_FOUND

## Depex 的运行机制

Depex 是运行时机制，不是编译期概念。PEI 调度器每轮扫描都会检查每个还没执行的 PEIM：它的 Depex 满足了吗？

- Depex = TRUE：永远满足，立即执行
- Depex = gJYTianCmosPpiGuid：查 PEI 数据库里这个 GUID 的 PPI 有没有被装过。没有就跳过，等别人装了再回来执行

调度器反复轮询，直到依赖满足或超时。依赖链可以多层：C 依赖 B 的 PPI、B 依赖 A 的 PPI，调度器自动找出 A → B → C 的执行顺序。

## 和 Library 的区别

关键差异在耦合时机：PPI 是运行时查找，Library 是编译期链接。

| | PPI | Library |
|---|---|---|
| 耦合时机 | 运行时 | 编译期 |
| 生产者和消费者 | 两个独立 PEIM | 同一个模块 |
| 注册 | InstallPpi() | LibraryMapping（DSC 里） |
| 查找 | LocatePpi(&Guid) | 链接器自动解析 |
| 顺序保证 | Depex | 不需要 |

PPI 适合两个独立模块之间传递功能；Library 适合封装可复用公共代码。一个消费者 PEIM 可以同时用编译期链接的库和运行时查找的 PPI。

## 常见报错速查

| 报错信息 | 原因 | 改法 |
|---|---|---|
| `Mandatory object missing - Package` | sdl 的 INFComponent 缺 Package | 补 `Package = "包名"` |
| `INFComponent xxx not defined` | LibraryMapping 的 Instance 写了 Part 名而非 INFComponent Name | Instance 写成 `包名.INFComponentName` |
| `File/directory not found: xxx.inf` | sdl File 和实际 .inf 文件名不一致 | 三个名字对齐：.inf 文件名、sdl File、cif INF 行 |
| `Value of xxxGuid is not found` | Depex 用到的 GUID 没在 .dec 里定义 | .dec 补 `[Guids]` 段 |
| 运行时生产者没执行 | 模块没进 FV | 检查 cif parts、INFComponent ModuleTypes |
| LocatePpi 返回 NOT_FOUND | 顺序反了 | 消费者 Depex 是否填了正确的 PPI GUID |
