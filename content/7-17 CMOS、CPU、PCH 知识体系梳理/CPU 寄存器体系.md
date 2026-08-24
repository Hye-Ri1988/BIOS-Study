---
publish: true
---
# CPU 寄存器体系

## 3.1 基本概念

寄存器是 CPU 内有限容量的高速存贮部件，用来暂存指令、数据和地址。

- **控制部件**：指令寄存器（IR）、程序计数器（PC）
- **算术及逻辑部件**：累加器（ACC）
- X86 CPU 常用寄存器：数据寄存器、指针寄存器、变址寄存器、指令指针寄存器、标志寄存器、段寄存器等

## 3.2 寄存器分类

**通用寄存器**

- AX/EAX/RAX — 累加器
- BX/EBX/RBX — 基址寄存器
- CX/ECX/RCX — 计数寄存器
- DX/EDX/RDX — 数据寄存器
- SI/ESI/RSI — 源变址寄存器
- DI/EDI/RDI — 目的变址寄存器
- SP/ESP/RSP — 栈指针寄存器
- BP/EBP/RBP — 基址指针寄存器

**段寄存器**

- CS — 代码段
- DS — 数据段
- ES — 附加段
- SS — 堆栈段
- FS / GS — 附加段（386+）

**标志寄存器 (EFLAGS/RFLAGS)**

- CF (Carry Flag) — 进位标志
- ZF (Zero Flag) — 零标志
- SF (Sign Flag) — 符号标志
- OF (Overflow Flag) — 溢出标志
- TF (Trap Flag) — 单步调试

**系统寄存器**

- GDTR — 全局描述符表寄存器
- IDTR — 中断描述符表寄存器
- CR0-CR4 — 控制寄存器
- DR0-DR7 — 调试寄存器
- MSR — 模型特定寄存器

**汇编操作示例**

```asm
MOV AX, 0x1234       ; AX = 0x1234
MOV BX, AX           ; BX = 0x1234
ADD AX, BX           ; AX = 0x2468
CMP AX, 0x3000       ; 比较
JZ  equal_label      ; ZF=1 则跳转
```

## 3.3 寄存器在 BIOS 调试中的意义

- DEBUG 工具用 `-r` 查看所有寄存器
- RU 工具可查看 CPU MSR 寄存器
- 通过寄存器值判断当前执行模式
- `CR0.PE=1` 表示已进入保护模式
- `EFLAGS.TF=1` 启用单步调试
