<div align="center">

![DREW-V Labs](.github/images/drewv-labs-github-banner-rounded.png)  

# RISC-V Edge Toolkit


![RISC-V Architecture](https://img.shields.io/badge/Architecture-RISC--V-orange?style=for-the-badge) ![Debian Unstable](https://img.shields.io/badge/OS-Debian_Unstable-red?style=for-the-badge) ![PostgreSQL Database](https://img.shields.io/badge/Database-PostgreSQL-blue?style=for-the-badge) ![Hailo-8 NPU](https://img.shields.io/badge/NPU-Hailo--8-blue?style=for-the-badge)  

</div>

---

## About  

`DREW-V Labs` is focused on the development of a RISC-V based edge AI and Data Brokerage toolkit that is designed to be used in a variety of edge computing environments. Our toolkit is designed to be used with a variety of hardware and software types, and is designed to be easily integrated into existing edge computing environments. We leverage Apple Silicon & Debian based development machines and favor Golang, Rust, & Python based languages to build robust light-but-mighty solutions to unleash the full power of RISC-V technology for open edge science & engineering R&D.

---

## Kit File Structure

```text
lildebbyhelpers/                → Core Debian Helpers
├── harden.sh                   → Removes default "user" from VF2 boards
└── pregame.sh                  → Updates <user> and <hostname> from default

nodes/                          → Node-specific provisioning scripts
├── sifive-p550-databroker/     → SiFive HiFive Premier P550 Data Broker
│   ├── flash-sd.sh             → SD card flashing utility
│   ├── deploy-forge.sh         → Pushes toolkit to remote nodes
│   └── forge/
│       └── forge-brackerbox-p550.sh  → Unified P550 Data Broker provisioning engine
├── starfive-vf2-databroker/    → StarFive VisionFive2 Databroker
│   ├── flash-sd.sh             → SD card flashing utility
│   ├── deploy-forge.sh         → Pushes toolkit to remote nodes
│   └── forge/
│       └── forge-brackerbench-vf2.sh  → Unified VF2 Databroker provisioning engine
└── starfive-vf2-hailo-ai/      → StarFive VisionFive2 + Hailo-8(L) Inference Engine
    ├── flash-sd.sh             → SD card flashing utility
    ├── deploy-forge.sh         → Pushes toolkit to remote nodes
    └── forge/
        └── forge-visionferret-h8.sh  → Unified Hailo-8 & RISC-V provisioning engine
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
