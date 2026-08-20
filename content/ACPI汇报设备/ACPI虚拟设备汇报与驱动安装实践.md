---
publish: true
---


> 主题：通过 ACPI 向 Windows 汇报一个虚拟设备，并编译驱动完成绑定（无黄标）

两个目标：

1. 固件侧单独建一个 Module（`OemJYTianPkg\JYTianVirtualDevice`），通过 ACPI 向系统汇报一个虚拟设备；
2. 驱动侧编译一个基础驱动并安装成功，设备管理器无黄标。


当前完成了任务目标，但是具体任务实践过程中的排错总结以及实现思路还未总结完毕。

 ![[img_v3_0214o_f2068f4c-382c-4acd-b1e8-f89f8d501f2g.jpg]]![[img_v3_0214o_207add7e-f3ad-4816-b6ee-17448beb116g.jpg]]![[img_v3_0214o_e0c8968e-0c76-4094-9997-2455cf8f177g.jpg]]