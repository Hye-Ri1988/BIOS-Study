---
publish: true
---
# PCIe — 高速串行总线

Peripheral Component Interconnect Express，高速串行点对点互连总线，替代 PCI/PCI-X。

- **分层架构**：物理层 → 数据链路层 → 事务层
- **最小单位**：Lane，可组合为 ×1/×4/×8/×16
- **全双工**通信，每 Lane 独立收发
- 支持热插拔、链路训练、电源管理
