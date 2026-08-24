# session_id: 50e4e9ec-f5fc-4281-9845-495bf9784573
classes: {
  zone_1: {
    style: {
      fill: "#F0F5FE"
      stroke: "#467AEE"
      font-color: "#333333"
      border-radius: 8
    }
  }
  zone_2: {
    style: {
      fill: "#F3F6FE"
      stroke: "#467AEE"
      font-color: "#333333"
      border-radius: 8
    }
  }
  zone_3: {
    style: {
      fill: "#F6F8FE"
      stroke: "#467AEE"
      font-color: "#333333"
      border-radius: 8
    }
  }
  zone_4: {
    style: {
      fill: "#F9FBFE"
      stroke: "#467AEE"
      font-color: "#333333"
      border-radius: 8
    }
  }
  zone_5: {
    style: {
      fill: "#FCFDFF"
      stroke: "#467AEE"
      font-color: "#333333"
      border-radius: 8
    }
  }
  entity: {
    style: {
      fill: "#FFFFFF"
      stroke: "#1F2937"
      font-color: "#333333"
      border-radius: 6
      shadow: true
    }
  }
  signal: {
    style: {
      fill: transparent
      font-color: "#6B7280"
    }
  }
}

# Intel 平台 UEFI 固件 GOP 与 HDMI 显示链路整体架构框图

# ========== 固件/BIOS 层 ==========
固件层: {
  class: zone_1
  label: 固件/BIOS 层（AMI AptioV）

  早期图形初始化: 早期图形初始化模块 {
    class: entity
    label: 早期图形初始化模块\nIntelGraphicsPeim（PEI 阶段）
    tooltip: POST logo 出现前点亮屏幕
  }

  图形输出协议驱动: 图形输出协议驱动 {
    class: entity
    label: 图形输出协议驱动\nIntelGopDriver（DXE 阶段）
    tooltip: 安装 GOP 协议，暴露线性帧缓冲基地址
  }

  视频BIOS表: 视频 BIOS 表（VBT） {
    class: entity
    label: 视频 BIOS 表（VBT）\nIntel 专有二进制显示配置
    tooltip: 含端口定义、HPD/DDC 开关、面板时序
  }

  平台策略初始化: 平台策略初始化 {
    class: entity
    label: 平台策略初始化\nGopPolicyInitDxe（DXE 阶段）
    tooltip: 负责 VBT 选择、开合盖逻辑
  }

  # 固件层内部关系
  平台策略初始化 -> 视频BIOS表: 选择 VBT
  视频BIOS表 -> 图形输出协议驱动: 按 GUID 读取
  图形输出协议驱动 -> 早期图形初始化: 协同点亮 {
    style.stroke-dash: 3
  }

  # 固件层内部协作说明（通过位置表达，不增加连线）
  固件协作说明: 固件层内部协作 {
    class: signal
    label: 策略初始化选择 VBT →\n协议驱动按 GUID 读取 VBT →\n安装 GOP 并配置 GPU
    style.fill: transparent
  }
}

# ========== GPU 硬件信号链 ==========
GPU硬件层: {
  class: zone_2
  label: GPU 硬件信号链（GOP 职责边界）

  显示处理器: 显示处理器（iGFX） {
    class: entity
    label: 显示处理器\n（iGFX/GFX 集成显卡）
    tooltip: 像素渲染单元
  }

  显示锁相环: 显示锁相环（DPLL/PLL） {
    class: entity
    label: 显示锁相环\n（DPLL/PLL）
    tooltip: 显示时钟生成单元
  }

  数字显示接口: 数字显示接口（DDI/PHY） {
    class: entity
    label: 数字显示接口\n（DDI/PHY）
    tooltip: 信号编码：HDMI 用 TMDS，DP/eDP 用 8b/10b
  }

  连接器: 连接器（物理接口） {
    class: entity
    label: 连接器（物理接口）\n端口 A/B/C/D
    tooltip: A=内屏 eDP；B/C=外接 HDMI/DP/DP++；D=DP（Type-C）
  }

  线缆: 线缆 {
    class: entity
    label: 线缆
    tooltip: 传输介质，无需 BIOS 参与
  }

  面板: 面板 {
    class: entity
    label: 面板
    tooltip: 最终显示，无需 BIOS 参与
  }

  # 主信号链（加粗）
  显示处理器 -> 显示锁相环: 像素数据 {
    style.stroke-width: 4
  }
  显示锁相环 -> 数字显示接口: 时钟+数据 {
    style.stroke-width: 4
  }
  数字显示接口 -> 连接器: TMDS/DP 信号 {
    style.stroke-width: 4
  }
  连接器 -> 线缆: 物理信号 {
    style.stroke-width: 4
  }
  线缆 -> 面板: 显示信号 {
    style.stroke-width: 4
  }

  # 边界标注通过位置表达，不增加连线

  # GOP 边界标注
  边界标注: GOP/BIOS 仅配置前三段 {
    class: signal
    label: GOP/BIOS 仅配置\n「显示处理器→显示锁相环→数字显示接口」\n线缆与面板由 OS/显示器自身处理
    style.fill: transparent
  }
}

# ========== 显示器侧通道 ==========
显示器侧通道: {
  class: zone_3
  label: 显示器侧通道

  热插拔检测: 热插拔检测（HPD） {
    class: entity
    label: 热插拔检测（HPD）
    tooltip: GPIO 引脚，检测显示器插拔，事件经 ACPI 通知 OS 驱动
  }

  显示数据通道: 显示数据通道（DDC/GMBUS） {
    class: entity
    label: 显示数据通道\n（DDC/GMBUS）
    tooltip: 基于 I2C 读 EDID；Intel 实现为图形单元内置 I2C 主机
  }

  扩展显示标识数据: 扩展显示标识数据（EDID） {
    class: entity
    label: 扩展显示标识数据（EDID）
    tooltip: 128 字节基础块 + CEA-861 扩展块；UEFI 定义三协议
  }

  # 侧通道关系

  显示数据通道 -> 扩展显示标识数据: 读取 EDID
}

# ========== OS 交接层 ==========
OS交接层: {
  class: zone_4
  label: OS 交接层

  操作区域: 操作区域（OpRegion） {
    class: entity
    label: 操作区域（OpRegion）\nBIOS 与 OS 显示驱动共享内存区
    tooltip: ASLS 寄存器写入物理地址；按信箱划分（头/ACPI/软SCI/ASLE/VBT）
  }

  启动图形资源表: 启动图形资源表（BGRT） {
    class: entity
    label: 启动图形资源表（BGRT）\nACPI 表
    tooltip: 固件写 logo 帧缓冲地址，实现图形驱动切换无闪烁
  }

  OS显示驱动: OS 显示驱动 {
    class: entity
    label: OS 显示驱动
    tooltip: 读取 OpRegion 与 BGRT 完成交接
  }

  # OS 交接关系

  操作区域 -> OS显示驱动: 读取 VBT/信箱

  启动图形资源表 -> OS显示驱动: 读取实现无闪烁切换
}

# ========== 跨层缝合 ==========
# 固件层 → GPU 硬件层（核心配置路径）
固件层.图形输出协议驱动 -> GPU硬件层.显示处理器: 配置寄存器/帧缓冲 {
  style.stroke-width: 4
}

# GPU 硬件层 → 显示器侧通道（合并为一条语义连接）
GPU硬件层.数字显示接口 -> 显示器侧通道.显示数据通道: HPD/DDC 通道

# 显示器侧通道 → 固件层（EDID 回传，通过工具提示表达）
显示器侧通道.扩展显示标识数据 -> 固件层.图形输出协议驱动: 分辨率/时序信息 {
  tooltip: EDID 决定 GOP 暴露的分辨率选项
}

# ========== 显示接口对比（边缘支撑） ==========
接口对比: {
  class: zone_5
  label: 显示接口对比（边缘说明）
  grid-columns: 3

  HDMI: HDMI {
    class: entity
    label: HDMI\nTMDS，4K@60Hz
  }

  DP: DP {
    class: entity
    label: DP\n8b/10b，8K@30Hz
  }

  eDP: eDP {
    class: entity
    label: eDP\n内屏
  }

  DP双模: DP++ {
    class: entity
    label: DP++\n双模
  }

  VGA: VGA {
    class: entity
    label: VGA\n模拟，已淘汰
  }
}
# === Auto-hoisted cross-container connections ===

固件层.图形输出协议驱动 -> OS交接层.操作区域: 建立共享内存（ASLS 指向）

固件层.图形输出协议驱动 -> OS交接层.启动图形资源表: 写入 logo 帧缓冲地址