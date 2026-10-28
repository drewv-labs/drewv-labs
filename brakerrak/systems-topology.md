<div align="center"> 

# Systems Topology  

</div>

*Updated: 2026-10-24*

This doc serves as capacity plan for **DREW-V Labs** hardware builds supporting open RISC-V Edge ML & Data Brokering R&D. We leverage automated Astrophotography, in addition to other projects, to field test and harden system and software designs. The Astro Field Lab specifications are listed below.

---

## Part I: "Research Rack" Design

**Design Target Completion Date**: `2027-01-01`

*Legend:*
* `$` next to a Node Name indicates that the node is currently on the acquisition list / backordered.
* `InO` = [In-Order Processing](https://en.wikipedia.org/wiki/Out-of-order_execution#In-order_processors)
* `OoO` = [Out-of-Order Processing](https://en.wikipedia.org/wiki/Out-of-order_execution#Out-of-order_processors)  
*(additional)*: [Classic RISC Pipeline](https://en.wikipedia.org/wiki/Classic_RISC_pipeline) & [Instruction Pipelining](https://en.wikipedia.org/wiki/Instruction_pipelining)
* Naming convention follows `[Role]-[tag]`:
  * **`BrakerBox-*`**: Production Data Broker ([PigeonCoop](https://github.com/drewv-labs/carrier-pigeons), [PostgreSQL](https://www.postgresql.org/), [MQTT](https://mqtt.org/), [NFS](https://en.wikipedia.org/wiki/Network_File_System) storage tiers).  
  *(bonus)*: [PGSimCity](https://github.com/NikolayS/pgsimcity)
  * **`BrakerBench-*`**: Dedicated Database & Microarchitecture Test Bench nodes.
  * **`VisionFerret-*`**: Dedicated Edge ML / NPU & RF DSP Test Bench nodes.

### 1. Networking Fabric
| Node | SpaceReq | OS | Hardware | Notes | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `LabWrt-R6S` | `1U` (U02 Shelf) | `OpenWrt` | [FriendlyElec NanoPi R6S](https://www.friendlyelec.com/index.php?route=product/product&product_id=28) (RK3588S 8GB / 32GB eMMC) | 2x 2.5GbE + 1x 1GbE RJ45 | Dedicated Lab router, firewall, & local DNS/DHCP authority |
| `LabSwitch` | `1U` (U01) | `Unmanaged` | [Sodola 26-Port Multi-Gig Switch](https://www.sodola-network.com/products/sodola-24-port-2-5gb-umanaged-switch-24x2-5g-base-t-ports-2x10g-sfp-160gbps-switching-capacity-port-isolation-iu-rack-mount-fanless-plug-play-multi-gig-unmanaged-ethernet-switch) (SL-SWTG0224AS) | 24x 2.5GbE RJ45 (Ports 1-24) + 2x 10GbE SFP+ Key Ports (Ports 25-26) | Core 160Gbps L2 switching backplane (`VLAN` port-isolation switch set to `OFF`; `SM` set to `10G`) |

### 2. Production Nodes (Rack + Desk-Tethered)
| Node | SpaceReq | OS | Hardware | Notes | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `BabbageBox-RTX` | `5U` (U11-U15) | `Linux Mint 22.3` | `Asus ROG Maximus XI Hero` (i9-9900K / 32GB DDR4) | EVGA RTX 3090 (24GB) + EVGA RTX 3080 Ti (12GB) + 2.5GbE PCIe NIC | Tensor Forge & ML Engineering ([PyTorch](https://pytorch.org/) training & [Hailo DFC](https://hailo.ai/products/hailo-software/hailo-ai-software-suite/#sw-dc) `.onnx` -> `.har` -> `.hef` compilation factory) |
| $`BrakerBox-Titan` | `1U` (U07) | `Debian Unstable` | [Milk-V Titan](https://milkv.io/titan) 64GB ECC DDR4 (UltraRISC UR-DP1000, RVA22 + H-Ext 1.0) | 8x UR-CP100 4-Wide OoO @ 2.0GHz + 24MB Cache + WD_Black SN850X 2TB (Native PCIe Gen4 x4) + 10GbE SFP+ PCIe NIC + Onboard BMC | Designated Main Lab Production Data Broker |
| `BigRed-WDR48` | `1U` (U08) | `Linux mdadm` | SilverStone 4-Bay USB 3.0 Enclosure (Set to Clear RAID) | 4x WD Red Plus 12TB CMR (48TB Raw / ~22TB Usable RAID 10) | `BrakerBox` Warm Storage Layer & NFS Vault (`LABEL=BIGRED_VAULT` mounted at `/mnt/bigred_wdr48`) |
| `LilBlu-WDB24` | `1U` (U09) | `Linux mdadm` | SilverStone 4-Bay USB 3.0 Enclosure (Set to Clear RAID) | 4x WD Blue 6TB (24TB Raw / ~11TB Usable RAID 10) | `BrakerBox` Cold Storage & Telemetry Archive (`LABEL=LILBLU_ARCH` mounted at `/mnt/lilblu_wdb24`) |
| `CoffeeCan-Proxmox` | `Desk` | `Proxmox VE` | `2013 Apple Mac Pro 6,1` (Intel Xeon / 64GB ECC DDR3) | Dual GbE RJ45 (Hardlined to `LabSwitch`) | Desk-side Lab Hypervisor positioned next to `ZedBook` for on-demand Lab VM & container provisioning |
| `ZedBook` | `Desk` | `macOS` | `Apple MacBook Pro M2 Max 96GB` + Pro Display XDR | 2.5GbE / 10GbE (Hardlined to `LabSwitch`) | Primary Engineering Workstation ([Zed](https://zed.dev/) is Life) & Local LLM Orchestration |

### 3. Testing & Benchmarking Nodes
| Node | SpaceReq | OS | Hardware | Notes | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `BrakerBench-VF2` | `1U` (U02 Shelf) | `Debian Unstable` | [StarFive VisionFive 2](https://www.starfivetech.com/en/index.php) 8GB (JH7110, RVA20 RV64GC Scalar) | 4x U74 2-Wide InO @ 1.5GHz + 2MB L2 + WD_Black SN750 2TB (Gen2 x1) | Data Broker Benchmarking: Baseline 2-Wide In-Order `RVA20` Scalar Control Node |
| `BrakerBench-P550` | `1U` (U03) | `Ubuntu 24.04` (Headless) | [HiFive Premier P550](https://www.sifive.com/development-platforms/hifive-premier-p550) 32GB (ESWIN EIC7700X, RVA20 RV64GC + Zba/Zbb)` | 4x P550 3-Wide OoO @ 1.4GHz + 4MB L3 + WD_Black SN850X 2TB (StarTech Gen3 x4) + Native 20 TOPS | Data Broker Benchmarking: 3-Wide Out-of-Order `RVA20` + Bitmanip target |
| $`BrakerBench-Titan` | `1U` (U05) | `Debian Unstable` | [Milk-V Titan](https://milkv.io/titan) 64GB ECC DDR4 (UltraRISC UR-DP1000, RVA22 + H-Ext 1.0) | 8x UR-CP100 4-Wide OoO @ 2.0GHz + 24MB Cache (8MB L2 + 16MB LLC) + WD_Black SN850X 1TB (Native PCIe Gen4 x4) + Onboard BMC | Data Broker Benchmarking: Pure Server/Workstation 4-Wide OoO (`RV64GCBHX`), large L2/LLC cache hierarchy, ECC DDR4-3200, native PCIe Gen4 NVMe (`~7.3 GB/s`), and KVM virtualization |
| $`BrakerBench-Jupiter1` | `1U` (U04) | `Debian Unstable` | [Milk-V Jupiter (first gen)](https://milkv.io/jupiter) 16GB (SpacemiT M1, RVA22 + RVV 1.0 256-bit)` | 8x X60 2-Wide InO @ 1.8GHz + 2MB L2 + WD_Black SN850X 1TB (Gen2 x2) + Native 2 TOPS | Data Broker Benchmarking: 2-Wide In-Order `RVA22` + 256-bit Vector target (metal-lid `M1` SKU; clampable via `mem=8G` and cpufreq 1.50GHz for 1:1 parity against `BrakerBench-VF2`) |
| $`BrakerBench-Jupiter2` | `1U` (U06) | `Debian Unstable` | [Milk-V Jupiter 2](https://milkv.io/jupiter2) 32GB (SpacemiT K3, RVA23 + RVV 1.0 1024-bit) | 8x X100 4-Wide OoO @ 2.4GHz + WD_Black SN850X 1TB (Gen3 x4) + Native 60 TOPS + 10GbE SFP+ | Data Broker & Edge AI Benchmarking: Flagship `RVA23` 4-Wide Out-of-Order + 1024-bit Vector + 60 TOPS NPU target |
| `VisionFerret-H8L` | `1U` (U02 Shelf) | `Debian Unstable` | [StarFive VisionFive 2](https://www.starfivetech.com/en/index.php) 8GB (JH7110, RVA20 RV64GC Scalar) | 4x U74 2-Wide InO @ 1.5GHz + M.2 PCIe [Hailo-8L](https://hailo.ai/products/ai-accelerators/hailo-8l-m-2-ai-acceleration-module-for-ai-light-applications/) (13 TOPS) | Edge AI Benchmarking: A/B Twin for testing Multi-Context PCIe DMA host-RAM spills (8GB native for parity; clampable via `mem=4G` to model sub-$200 entry AI kits) |
| `VisionFerret-H8` | `1U` (U02 Shelf) | `Debian Unstable` | [StarFive VisionFive 2](https://www.starfivetech.com/en/index.php) 8GB (JH7110, RVA20 RV64GC Scalar) | 4x U74 2-Wide InO @ 1.5GHz + M.2 PCIe [Hailo-8](https://hailo.ai/products/ai-accelerators/hailo-8-m2-ai-acceleration-module/) (26 TOPS) | Edge AI Benchmarking: $300 "Sweet-Spot" AI Kit tier (Single-Context on-chip SRAM execution) |

### 4. 15U Rack Stack Elevation Model
~~~text
U15 |---------------------------------------------------------------|
U14 |                                                               |
U13 |                       BabbageBox-RTX                          |
U12 |---------------------------------------------------------------| 
U11 [                        VentedSpacer                           ]
U10 [                      BrakerBox-Titan                          ]
U09 [                        BigRed-WDR48                           ]
U08 [                        LilBlu-WDB24                           ]
U07 [                     BrakerBench-Titan                         ]
U06 [                    BrakerBench-Jupiter2                       ]
U05 [                    BrakerBench-Jupiter1                       ]
U04 [                      BrakerBench-P550                         ]
U03 [                        VentedSpacer                           ]
U02 [   LabWrt-R6S  |  VFerret-H8  |  VFerret-H8L  |  BBench-VF2    ]
U01 [                        Sodola Switch                          ]
    -----------------------------------------------------------------
    + Desk-Tethered to U01 Switch: [ ZedBook ] & [ CoffeeCan-Proxmox ]
~~~

### 5. Experimental Normalization & Microarchitecture Matrix (`BrakerBench` Series)
| Node | Core & Pipeline Width | ISA Profile & Extensions | Cache Hierarchy | NVMe Bus Ceiling | Parity Normalization Knobs |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `BrakerBench-VF2` | 4x SiFive U74 (2-Wide In-Order @ 1.5 GHz) | `RVA20` (`RV64GC` Scalar) | 32KB L1I/D, 2MB Shared L2 | PCIe Gen2 x1 (~400 MB/s) | Baseline Control (`shared_buffers = 2GB`, `work_mem = 64MB`, volatile RAM `journald`) |
| `BrakerBench-P550` | 4x SiFive P550 (3-Wide Out-of-Order @ 1.4 GHz) | `RVA20 + Zba/Zbb` (`RV64GC_Zba_Zbb`) | 32KB L1 + 256KB L2/core, 4MB Shared L3 | PCIe Gen3 x4 (~3,200 MB/s) | Run `ALTER SYSTEM SET shared_buffers = '2GB'` (or `mem=8G`) to isolate 3-Wide OoO ROB vs. `VF2` |
| `BrakerBench-Titan` | 8x UltraRISC UR-CP100 (4-Wide Out-of-Order @ 2.0 GHz) | `RVA22 + H-Ext 1.0` (`RV64GCBHX` Server) | 64KB L1 + 512KB L2/core, 8MB L2 + 16MB LLC | PCIe Gen4 x4 (~7,300 MB/s) | Isolates 4-Wide OoO + massive 24MB Server Cache + full Gen4 SN850X throughput (without Vector/NPU) |
| `BrakerBench-Jupiter2` | 8x SpacemiT X100 (4-Wide Out-of-Order @ 2.4 GHz) | `RVA23` (`RV64GCBV` + 1024-bit `RVV 1.0`) | 64KB L1, 4MB L2 (2MBx2) | PCIe Gen3 x4 (~3,200 MB/s) | Isolates `RVA23` 1024-bit Vector + 60 TOPS NPU against `BrakerBench-Titan` and `BrakerBench-P550` |
| `BrakerBench-Jupiter1` | 8x SpacemiT X60 (2-Wide In-Order @ 1.8 GHz) | `RVA22` (`RV64GCVB` + 256-bit `RVV 1.0`) | 32KB L1I/D, 2MB L2 (1MBx2) | PCIe Gen2 x2 (~800 MB/s) | Pass `mem=8G`, `maxcpus=4`, and pin `scaling_max_freq=1500000` to isolate `RVA22 + RVV 1.0` vs. `VF2` |


----

Made with ♥️ by
```py
DREW-V := {
  "Simplicity in the Architecture",
  "Efficiency in the Engineering",
  "Purity in the Science",
  "Audacity in the Art",
  "Life in the Logic"
}
```
