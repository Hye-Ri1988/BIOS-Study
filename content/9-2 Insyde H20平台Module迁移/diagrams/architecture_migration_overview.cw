# session_id: dac0d8b1-9741-41cc-8f80-d47886e73294
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

# ============ Layer 1: Top-level Modules/Applications ============
top_modules: 顶层模块 / 应用 {
  class: zone_1
  direction: right

  ami_platform: AMI 平台 {
    class: zone_2
    direction: down

    ami_mydxe: MyDxeDriver {
      class: entity
    }
    ami_cmos: CmosDxe {
      class: entity
    }
    ami_setup: Setup 表单 {
      class: entity
    }
  }

  insyde_platform: Insyde H2O 平台 {
    class: zone_2
    direction: down

    h2o_mydxe: MyDxeDriver {
      class: entity
    }
    h2o_cmos: CmosDxe {
      class: entity
    }
    h2o_setup: Setup 表单 {
      class: entity
    }
  }
}

# ============ Layer 2: EDKII Base (Shared Build Semantics) ============
edkii_base: EDKII 底层（共享编译体系） {
  class: zone_1

  edkii_files: dec / inf / dsc / fdf（两地语义一致） {
    class: entity
  }
}

# ============ Layer 3: Project Definition Layer ============
project_def: 项目定义层 {
  class: zone_1
  direction: right

  h2o_def: H2O 项目定义 {
    class: zone_2
    direction: down

    h2o_hii: HII/IFR + .uni Setup 表单（需重写） {
      class: entity
    }
    h2o_env: .env DEFINE 开关集中管理 {
      class: entity
    }
    h2o_dsc: "dsc [Components] 模块清单" {
      class: entity
    }
  }

  ami_def: AMI 项目定义 {
    class: zone_2
    direction: down

    ami_sd: .sd + .uni Setup 表单 / 多语言 {
      class: entity
    }
    ami_sdl: .sdl 模块清单 + TOKEN 开关 {
      class: entity
    }
    ami_cif: .cif 组件/工程树清单 {
      class: entity
    }
  }
}

# ============ Layer 4: Project Integration ============
project_int: 工程集成 {
  class: zone_1

  project_files: "Project.dsc / Project.fdf !import Oem/OemPkg" {
    class: entity
  }
}

# ============ Cross-Layer Connections ============
# AMI modules -> directly migratable -> H2O modules
top_modules.(ami_platform.ami_mydxe -> insyde_platform.h2o_mydxe): 基本可直接迁移
top_modules.(ami_platform.ami_cmos -> insyde_platform.h2o_cmos): 基本可直接迁移
top_modules.(ami_platform.ami_setup -> insyde_platform.h2o_setup): 基本可直接迁移

# EDKII base -> H2O project definition
edkii_base.edkii_files -> project_def.h2o_def.h2o_hii: dec/inf 小修、dsc/fdf 手写

# AMI project definition -> H2O project definition
project_def.(ami_def.ami_sd -> h2o_def.h2o_hii): 语法不同需重写
project_def.(ami_def.ami_sdl -> h2o_def.h2o_env): 拆分映射
project_def.(ami_def.ami_sdl -> h2o_def.h2o_dsc): 拆分映射
project_def.ami_def.ami_cif -> project_def: 无对应，丢弃/改写为 dsc+env

# Project definition layer -> Project integration
project_def.h2o_def.h2o_dsc -> project_int.project_files: OemPkg 挂接