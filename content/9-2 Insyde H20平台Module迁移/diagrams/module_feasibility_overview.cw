# session_id: 7c02a659-0460-43c5-9f54-d36cf9731097
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
      stroke: "#E8ECF5"
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

direction: down

# ============ Zone 1: 可直接编译 ============
direct_compile: 可直接编译 {
  class: zone_1
  shape: rectangle
  style: {
    border-radius: 12
  }

  MyLib: MyLib {
    class: entity
  }
  MyCalcLib: MyCalcLib {
    class: entity
  }
  MyPrintLib: MyPrintLib {
    class: entity
  }
  MyStackGuardLib: MyStackGuardLib {
    class: entity
  }
  CmosPpi: CmosPpi {
    class: entity
  }
  CmosDxe: CmosDxe {
    class: entity
  }
  MyDxeDriver: MyDxeDriver {
    class: entity
  }
  MyCalcDxe: MyCalcDxe {
    class: entity
  }
  MyGop: MyGop {
    class: entity
  }
  ReadDiskMedia: ReadDiskMedia {
    class: entity
  }
  MyCalcPei: MyCalcPei {
    class: entity
  }
  MyPeiM: MyPeiM {
    class: entity
  }
  MyUefiApp: MyUefiApp {
    class: entity
  }
  PciEnumAPP: PciEnumAPP {
    class: entity
  }
  ReadEcApp: ReadEcApp {
    class: entity
  }
  USBEnum: USBEnum {
    class: entity
  }
  MyVirtualDevice: MyVirtualDevice {
    class: entity
  }
  grid-columns: 4
}

# ============ Zone 2: 需重映射平台包 ============
remap: 需重映射平台包 {
  class: zone_2
  shape: rectangle
  style: {
    border-radius: 12
  }

  MemSpdDxe: MemSpdDxe {
    class: entity
  }
  UsbPower: UsbPower {
    class: entity
  }
  gpio_note: {
    class: entity
    shape: rectangle
    label: |`md
      **GPIO 依赖**
      - GpioLib.h 找不到
      - GpioConfig.h 找不到
      - Pins/GpioPinsVer4S.h 找不到
      - 需换 H2O/Intel GPIO 头
      - 或修改代码适配
    `|
  }
  grid-columns: 2
}

# ============ Zone 3: AMI 强依赖 ============
ami_dep: AMI 强依赖（建议剔除） {
  class: zone_3
  shape: rectangle
  style: {
    border-radius: 12
  }

  MyRTServices: MyRTServices {
    class: entity
  }
  MyStackGuardDemo: MyStackGuardDemo {
    class: entity
  }
  MyTimerDxe: MyTimerDxe {
    class: entity
  }
  MyLogoDxe: MyLogoDxe {
    class: entity
  }
  MyGPIO: MyGPIO {
    class: entity
  }
  MySmbios: MySmbios {
    class: entity
  }
  MySmbiosDxe: MySmbiosDxe {
    class: entity
  }
  MySmi: MySmi {
    class: entity
  }
  JYTianSetupModule: JYTianSetupModule {
    class: entity
  }
  grid-columns: 3
}

# ============ 组间链路 ============
direct_compile -> remap: 需平台包适配 {
  style: {
    stroke-width: 2
  }
}

remap -> ami_dep: 强依赖无法直接迁移 {
  style: {
    stroke-width: 2
  }
}