# DREW-V Labs RISC-V Edge AI Toolkit

![RISC-V Architecture](https://img.shields.io/badge/Architecture-RISC--V-orange?style=for-the-badge) ![Hailo-8 NPU](https://img.shields.io/badge/NPU-Hailo--8-blue?style=for-the-badge) ![Debian Unstable](https://img.shields.io/badge/OS-Debian_Unstable-red?style=for-the-badge) ![Astral uv](https://img.shields.io/badge/Env-Astral_uv-purple?style=for-the-badge)

## About  
This repo represents a collection of tools for working with a variety of software and hardware types, specifically Debian based RISC-V Edge AI research.  

Currently, this lab focuses on using StarFive's VisionFive 2 SBC powered by the JH7110 SoC (RV64GC instruction set) but plans on expanding available hardware and RISC-V chip and instruction sets.  

The lab utilizes a hybrid Apple Silicon Macs and Debian based development machines.  

## Kit File Structure

```text
lildebbyhelpers/                → Core Debian Helpers
├── harden.sh                   → Removes default "user" from VF2 boards
└── pregame.sh                  → Updates <user> and <hostname> from default

sifive-p550-databroker/         → SiFive HiFive Premier P550 Data Broker
├── flash-sd.sh                 → SD card flashing utility
├── deploy-forge.sh             → Pushes toolkit to remote nodes
└── forge/
    └── forge-node.sh           → Unified P550 Data Broker "BrakerBox" provisioning engine

vf2-hailo8-kit/                 → StarFive VisionFive2 + Hailo-8(L) Inference Engine
├── flash-sd.sh                 → SD card flashing utility
├── deploy-forge.sh             → Pushes toolkit to remote nodes
└── forge/
    └── forge-node.sh           → Unified Hailo-8 & RISC-V provisioning engine
```


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
