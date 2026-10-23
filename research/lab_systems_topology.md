# DREW-V Labs Systems Topology  

*as of 2026-10-23*  

This doc is for central truth & planning out personal lab builds for distributed open RISC-V Edge AI & Data Brokering R&D.

---
 
## 15U Research Lab Rack Target Design: 

**Design Target Complete Date**: `2027-01-01` 

`~` next to Node Name indicates that the Node is still on the wish list. 

### Networking
| Node | SpaceReq | OS | Hardware | Notes | Description |  
| ---- | -------- | -- | -------- | ----- | ----------- |
| `LabWrt-R6S` | `1U` | `OpenWrt` | `NanoPi R6S` | `2x 2.5gbps ETH Ports` | Lab router
| `Lab Switch` | `1U` | - | `Sodola 22port 2.5gbps switch` | `2x 10gbps key ports` | -

### Production Nodes
| Node | SpaceReq | OS | Hardware | Notes | Description |  
| ---- | -------- | -- | -------- | ----- | ----------- |
| `BabbageBox-RTX` | `5U` | `Linux Mint 22.3` | `Asus MaximusXI 32GB i9-9900k` | `RTX 3090` + `RTX 3080 Ti` + `2.5gbps PCIe Net` | Tensor Forge/ML Engineering
| ~`BrackerBox-J2` | `1U` | `Debian` | `Milk-V Jupiter 2 32GB RVA23+RVV1.0(1024bit Vector)` | `4-Wide OoO` + `WD_Black SN850X 2TB` + `Native 60TOPS` | Main Lab Data Broker; Will be using SiFive HiFive Premier P550 32GB board (`BrackerBox-P550`) until can source one; Hella backordered due to RAM shortages
| `BigRed-WDR48` | `1U` | - | `Silverstone USB3.0 RAID` | `4x WD Red 12TB (48TB)` | BrackerBox Warm storage layer
| `LilBlu-WDB24` | `1U` | - | `Silverstone USB3.0 RAID` | `4x WD Blue 6TB (24TB)` | BrackerBox Cold storage layer

### Testing & Benchmarking
| Node | SpaceReq | OS | Hardware | Notes | Description |  
| ---- | -------- | -- | -------- | ----- | ----------- |
| ~`BrackerBench-J2` | `1U` | `Debian` | `Milk-V Jupiter 2 32GB RVA23 + RVV1.0 (1024bit Vector)` | `4 Wide OoO` + `WD_Black SN850X 1TB` + `Native 60TOPS` | Data Broker Benchmarking
| ~`BrackerBench-J1` | `1U` | `Debian` | `Milk-V Jupiter 1 8GB RVA22 + RVV1.0 (256bit Vector)` | `2-Wide InO` + `WD_Black SN850X 1TB` + `Native 2TOPS` | Data Broker Benchmarking
| `BrackerBench-P550` | `1U` | `Ubuntu` | `SiFive Premier P550 32GB RVA20 (RV76GC + Zba/Zbb)` | `3-Wide OoO` + `WD_Black SN850X 1TB` + `Native 20TOPS` + `3 Wide OoO Proc` | Data Broker Benchmarking
| `BrackerBench-VF2` | `1U` | `Debian` | `StarFive VisionFive2 8GB RVA20 (RV64GC Scalar)` | `2-Wide InO` + `WD_Black SN750 1TB` | Data Broker Benchmarking
| `VisionFerret-H8` | `1U` | `Debian` | `StarFive VisionFive2 8GB RVA20 (RV64GC Scalar)` | `2-Wide InO` + `PCIe Hailo-8 26TOPS` | Edge ML Benchmarking
| ~`VisionFerret-H8L` | `1U` | `Debian` | `StarFive VisionFive2 8GB RVA20 (RV64GC Scalar)` | `2-Wide InO` + `PCIe Hailo-8L 13TOPS` | Edge ML Benchmarking

### Rack Stack Model
```
U15 |---------------------------------------------------------------|
U14 |                                                               |
U13 |                       BabbageBox-RTX                          |
U12 |                                                               |
U11 |---------------------------------------------------------------|
U10 [                        VentedSpacer                           ]
U09 [                        LilBlu-WDB24                           ]
U08 [                        BigRed-WDR48                           ]
U07 [                        BrackerBox-J2                          ]
U06 [                       BrackerBench-J2                         ]
U05 [                       BrackerBench-J1                         ]
U04 [                      BrackerBench-P550                        ]
U03 [                        VentedSpacer                           ]
U02 [   LabWrt-R6S  |  VFerret-H8  |  VFerret-H8L  |  BBench-VF2    ]
U01 [                        Sodola Switch                          ]
    -----------------------------------------------------------------
```
