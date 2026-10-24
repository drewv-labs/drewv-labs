<div align="center"> 

![DREW-V Labs](https://github.com/drewv-labs/drewv-labs-toolkit/blob/main/.github/images/drewv-labs-github-banner-rounded.png)  

# Systems Topology  

</div>

*as of 2026-10-24*

This doc serves as the central source of truth and capacity plan for DREW-V Labs hardware builds supporting distributed open RISC-V Edge AI, Hardware-Software Co-Design, Astrophotography Edge Compute, and Data Brokering R&D.

---

## Part I: 15U Research Lab Rack Target Design

**Design Target Complete Date**: `2027-01-01`

*Legend:*
* `~` next to a Node Name indicates that the node is currently on the acquisition wishlist / backordered.
* Naming convention follows `[Role]-[tag]`:
  * **`BrackerBox-*`**: Production Data Broker (`PigeonCoop`, PostgreSQL 18, MQTT, NFS storage tiers).
  * **`BrackerBench-*`**: Dedicated Database & Microarchitecture Test Bench nodes.
  * **`VisionFerret-*`**: Dedicated Edge AI / NPU & RF DSP Test Bench nodes.

---


### 1. Networking Fabric
| Node | SpaceReq | OS | Hardware | Notes | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `LabWrt-R6S` | `1U` (U02 Shelf) | `OpenWrt` | `FriendlyElec NanoPi R6S (RK3588S 8GB / 32GB eMMC)` | `2x 2.5GbE + 1x 1GbE RJ45` | Dedicated Lab router, firewall, & local DNS/DHCP authority (`10.0.10.0/24`, `.lab` domain) |
| `Lab Switch` | `1U` (U01) | `Unmanaged` | `Sodola 26-Port Multi-Gig Switch (SL-SWTG0224AS)` | `24x 2.5GbE RJ45 (Ports 1-24)` + `2x 10GbE SFP+ Key Ports (Ports 25-26)` | Core 160Gbps L2 switching backplane (`VLAN` port-isolation switch set to `OFF`; `SM` set to `10G`) |

---

### 2. Production Nodes (Rack + Desk-Tethered)
| Node | SpaceReq | OS | Hardware | Notes | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `BabbageBox-RTX` | `5U` (U11-U15) | `Linux Mint 22.3` | `Asus ROG Maximus XI Hero (i9-9900K / 32GB DDR4)` | `EVGA RTX 3090 (24GB)` + `EVGA RTX 3080 Ti (12GB)` + `2.5GbE PCIe NIC` | Tensor Forge & ML Engineering (`Caroline-V` PyTorch training & Hailo DFC `.onnx` -> `.har` -> `.hef` compilation factory) |
| ~`BrackerBox-T1` | `1U` (U07) | `Debian / Ubuntu` | `Milk-V Titan 64GB ECC DDR4 (UltraRISC UR-DP1000, RVA22 + H-Ext 1.0)` | `8x UR-CP100 4-Wide OoO @ 2.0GHz` + `24MB Cache` + `WD_Black SN850X 2TB (Native PCIe Gen4 x4)` + `10GbE SFP+ NIC` + `Onboard BMC` | Designated Main Lab Production Data Broker (`PigeonCoop`, PostgreSQL 18, MQTT, NFS); fulfilled in the interim by `BrackerBench-P550` (`10.0.10.97`) |
| `BigRed-WDR48` | `1U` (U08) | `Linux mdadm` | `SilverStone 4-Bay USB 3.0 Enclosure (Set to Clear RAID)` | `4x WD Red Plus 12TB CMR (48TB Raw / ~22TB Usable RAID 10)` | `BrackerBox` Warm Storage Layer & NFS Vault (`LABEL=BIGRED_VAULT` mounted at `/mnt/bigred_wdr48`) |
| `LilBlu-WDB24` | `1U` (U09) | `Linux mdadm` | `SilverStone 4-Bay USB 3.0 Enclosure (Set to Clear RAID)` | `4x WD Blue 6TB (24TB Raw / ~11TB Usable RAID 10)` | `BrackerBox` Cold Storage & Telemetry Archive (`LABEL=LILBLU_ARCH` mounted at `/mnt/lilblu_wdb24`) |
| `CoffeeCan-Proxmox` | `Desk` | `Proxmox VE` | `2013 Apple Mac Pro 6,1 (Intel Xeon / 64GB ECC DDR3)` | `Dual GbE RJ45` (Hardlined to `Lab Switch`) | Desk-side Lab Hypervisor positioned next to `ZedBook` for on-demand Lab VM & container provisioning |
| `ZedBook` | `Desk` | `macOS` | `Apple MacBook Pro 16" (M2 Max / Pro Display XDR / CalDigit E5 TB5)` | `2.5GbE / 10GbE` (Hardlined to `Lab Switch`) | Primary Engineering Workstation, Siril Astrophotography Processing, & Local LLM Orchestration |

---

### 3. Testing & Benchmarking Nodes
| Node | SpaceReq | OS | Hardware | Notes | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| ~`BrackerBench-J2` | `1U` (U06) | `Debian` | `Milk-V Jupiter 2 32GB (SpacemiT K3, RVA23 + RVV 1.0 1024-bit)` | `8x X100 4-Wide OoO @ 2.4GHz` + `WD_Black SN850X 1TB (Gen3 x4)` + `Native 60 TOPS` | Data Broker Benchmarking: Flagship `RVA23` 4-Wide Out-of-Order + 1024-bit Vector + 60 TOPS NPU target |
| ~`BrackerBench-T1` | `1U` (U05) | `Debian / Ubuntu` | `Milk-V Titan 64GB ECC DDR4 (UltraRISC UR-DP1000, RVA22 + H-Ext 1.0)` | `8x UR-CP100 4-Wide OoO @ 2.0GHz` + `24MB Cache (8MB L2 + 16MB LLC)` + `WD_Black SN850X 1TB (Native PCIe Gen4 x4)` + `Onboard BMC` | Data Broker Benchmarking: Pure Server/Workstation 4-Wide OoO (`RV64GCBHX`), large L2/LLC cache hierarchy, ECC DDR4-3200, native PCIe Gen4 NVMe (`~7.3 GB/s`), and KVM virtualization |
| ~`BrackerBench-J1` | `1U` (U04) | `Debian` | `Milk-V Jupiter 1 16GB (SpacemiT M1, RVA22 + RVV 1.0 256-bit)` | `8x X60 2-Wide InO @ 1.8GHz` + `2MB L2` + `WD_Black SN850X 1TB (Gen2 x2)` + `Native 2 TOPS` | Data Broker Benchmarking: 2-Wide In-Order `RVA22` + 256-bit Vector target (metal-lid `M1` SKU; clampable via `mem=8G` and `cpufreq 1.50GHz` for 1:1 parity against `BrackerBench-VF2`) |
| `BrackerBench-P550` | `1U` (U03) | `Ubuntu 24.04` (Headless) | `SiFive HiFive Premier P550 32GB (ESWIN EIC7700X, RVA20 RV64GC + Zba/Zbb)` | `4x P550 3-Wide OoO @ 1.4GHz` + `4MB L3` + `WD_Black SN850X 2TB (StarTech Gen3 x4)` + `Native 20 TOPS` | Data Broker Benchmarking: 3-Wide Out-of-Order `RVA20` + Bitmanip target (housed in SilverStone `SST-RM100` 1U; currently pulling interim `BrackerBox-P550` duty at `10.0.10.97`) |
| `BrackerBench-VF2` | `1U` (U02 Shelf) | `Debian` | `StarFive VisionFive 2 8GB (JH7110, RVA20 RV64GC Scalar)` | `4x U74 2-Wide InO @ 1.5GHz` + `2MB L2` + `WD_Black SN750 2TB (Gen2 x1)` | Data Broker Benchmarking: Baseline 2-Wide In-Order `RVA20` Scalar Control Node (passive aluminum case; ~42C idle / ~60C full load) |
| `VisionFerret-H8` | `1U` (U02 Shelf) | `Debian` | `StarFive VisionFive 2 8GB (JH7110, RVA20 RV64GC Scalar)` | `4x U74 2-Wide InO @ 1.5GHz` + `M.2 PCIe Hailo-8 (26 TOPS)` | Edge ML Benchmarking: $300 "Sweet-Spot" AI Kit tier (Single-Context on-chip SRAM execution) & 20.1 MHz RF Observatory |
| `VisionFerret-H8L` | `1U` (U02 Shelf) | `Debian` | `StarFive VisionFive 2 8GB (JH7110, RVA20 RV64GC Scalar)` | `4x U74 2-Wide InO @ 1.5GHz` + `M.2 PCIe Hailo-8L (13 TOPS)` | Edge ML Benchmarking: A/B Twin for testing Multi-Context PCIe DMA host-RAM spills (8GB native for parity; clampable via `mem=4G` to model sub-$200 entry AI kits) |

---

### 4. 15U Rack Stack Elevation Model
~~~text
U15 |---------------------------------------------------------------|
U14 |                                                               |
U13 |                       BabbageBox-RTX                          |
U12 |                                                               |
U11 |---------------------------------------------------------------|
U10 [                        VentedSpacer                           ]
U09 [                        LilBlu-WDB24                           ]
U08 [                        BigRed-WDR48                           ]
U07 [                        BrackerBox-T1                          ]
U06 [                       BrackerBench-J2                         ]
U05 [                       BrackerBench-T1                         ]
U04 [                       BrackerBench-J1                         ]
U03 [                      BrackerBench-P550                        ]
U02 [   LabWrt-R6S  |  VFerret-H8  |  VFerret-H8L  |  BBench-VF2    ]
U01 [                        Sodola Switch                          ]
    -----------------------------------------------------------------
    + Desk-Tethered to U01 Switch: [ ZedBook ] & [ CoffeeCan-Proxmox ]
~~~

---

### 5. Experimental Normalization & Microarchitecture Matrix (`BrackerBench` Series)
| Node | Core & Pipeline Width | ISA Profile & Extensions | Cache Hierarchy | NVMe Bus Ceiling | Parity Normalization Knobs |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `BrackerBench-VF2` | 4x SiFive U74 (2-Wide In-Order @ 1.5 GHz) | `RVA20` (`RV64GC` Scalar) | 32KB L1I/D, 2MB Shared L2 | PCIe Gen2 x1 (~400 MB/s) | Baseline Control (`shared_buffers = 2GB`, `work_mem = 64MB`, volatile RAM `journald`) |
| `BrackerBench-J1` | 8x SpacemiT X60 (2-Wide In-Order @ 1.8 GHz) | `RVA22` (`RV64GCVB` + 256-bit `RVV 1.0`) | 32KB L1I/D, 2MB L2 (1MBx2) | PCIe Gen2 x2 (~800 MB/s) | Pass `mem=8G`, `maxcpus=4`, and pin `scaling_max_freq=1500000` to isolate `RVA22 + RVV 1.0` vs. `VF2` |
| `BrackerBench-P550` | 4x SiFive P550 (3-Wide Out-of-Order @ 1.4 GHz) | `RVA20 + Zba/Zbb` (`RV64GC_Zba_Zbb`) | 32KB L1 + 256KB L2/core, 4MB Shared L3 | PCIe Gen3 x4 (~3,200 MB/s) | Run `ALTER SYSTEM SET shared_buffers = '2GB'` (or `mem=8G`) to isolate 3-Wide OoO ROB vs. `VF2` |
| `BrackerBench-T1` | 8x UltraRISC UR-CP100 (4-Wide Out-of-Order @ 2.0 GHz) | `RVA22 + H-Ext 1.0` (`RV64GCBHX` Server) | 64KB L1 + 512KB L2/core, 8MB L2 + 16MB LLC | PCIe Gen4 x4 (~7,300 MB/s) | Isolates 4-Wide OoO + massive 24MB Server Cache + full Gen4 SN850X throughput (without Vector/NPU) |
| `BrackerBench-J2` | 8x SpacemiT X100 (4-Wide Out-of-Order @ 2.4 GHz) | `RVA23` (`RV64GCBV` + 1024-bit `RVV 1.0`) | 64KB L1, 4MB L2 (2MBx2) | PCIe Gen3 x4 (~3,200 MB/s) | Isolates `RVA23` 1024-bit Vector + 60 TOPS NPU against `BrackerBench-T1` and `BrackerBench-P550` |

---

## Part II: `AdaLovespace` Distributed Field Astrophotography Cluster

While the Lab is focused on general RISC-V Edge AI & Data Brokerage research, we leverage astrophotography for field deployments and testing. Astrophotography is a discipline that requires unrelenting precision and encompasses a wide range of technical challenges that help strengthen the Lab's research tracks. For example, Out-of-Order processing is peak for high throughput PostgreSQL operations however the In-Order processing of the VisionFive2 + Hailo-8 AI kit (Caroline-V/VisionFerret-H8) provides lower power inferencing in the field, saving that precious battery pack. Also, space is badass and training cheap open source hardware and software to operate an imaging rig is fun, I highly recommend it! :)

Split physically into `AdaStack` (stationary base-camp compute stack with active push-pull fan cooling) and `AdaScope` (lightweight, vibration-free passive-cooled payload riding on the Optical Tube Assembly), linked across the mount hinge by a single PoE Ethernet hardline.


---

### 1. `AdaStack` (Stationary Base-Camp Stack)
| Node | Cooling | OS | Hardware | Notes | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `RadiaWrt` | `Active` | `OpenWrt` | `BananaPi OpenWrt One` | `PoE Injector + Wi-Fi AP` | Field network router, DHCP authority, & single-cable PoE supplier to `AdaScope` |
| `Caroline-V` | `Active` (4x 40mm Top + 1x 120mm Bottom Noctua) | `Debian` | `StarFive VisionFive 2 8GB (RVA20)` | `M.2 Hailo-8 (26 TOPS)` + `BeQuiet Heatsink` + `PoE Texas HAT` | Production Field Edge AI Inference Engine (real-time sub-frame grading, cloud/satellite rejection, & guiding telemetry wrapped by `CarrierPigeons`) |
| `JakeBase-Pi` -> ~`JakeBase-V` | `Active` | `Debian` | `Raspberry Pi 5` -> transitioning to `StarFive VisionFive 2 8GB` | `WD_Black SN770 1TB NVMe` | Field Data Broker & FITS Ingestion Vault (`PigeonCoop` field instance + PostgreSQL + local SMB/NFS staging) |
| `MargiStars` -> ~`MargiMaestro` | `Active` | `Linux` | `Intel N100 16GB MiniPC` -> transitioning to `RISC-V SBC` | `Headless INDI / Ekos` | Observatory Sequencer & Orchestrator (slated to transition from KStars/Ekos GUI on N100 to headless RISC-V `MargiMaestro` running `MaestroEngine`) |

---

### 2. `AdaScope` (On-OTA Telescope Payload — Zero-Vibration Passive Cooling)
| Node | Cooling | OS | Hardware | Notes | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `AdaCtrl` | `Passive Heatsink` | `Linux` | `SBC + PoE Splitter` | `USB3 to ZWO ASI2600MC Duo / Focuser / Filter` | On-scope INDI hardware controller powered via PoE hardline from `RadiaWrt` |
| `MaryGuider` | `Passive Heatsink` | `Linux` | `Dedicated Guiding SBC` | `USB-ETH Gadget Tether (usb0) to AdaCtrl` | Dedicated PHD2 multi-star autoguiding compute node linked point-to-point to `AdaCtrl` |
