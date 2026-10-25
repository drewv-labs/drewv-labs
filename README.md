<div align="center">

![DREW-V Labs](https://github.com/drewv-labs/drewv-labs-toolkit/blob/main/.github/images/drewv-labs-github-banner.png)  

# RISC-V Edge Toolkit

</div>

## About  

**DREW-V Labs** is focused on the development of a RISC-V based Edge ML and Data Brokering R&D. This toolkit is designed to be used with a variety of hardware and software types, and is designed to be easily integrated into existing edge computing environments. We leverage Apple Silicon & Debian based development machines and favor Golang, Rust, & Python based languages to build robust light-but-mighty solutions to unleash the full power of RISC-V technology for the open edge science & engineering frontier.

---

## Kit File Structure

~~~text
helpers/                      → Shared Helper Scripts
├── deb/
│   └── pregame.sh            → Updates <user> and <hostname> from default
└── vf2/
    ├── fix-user.sh           → Removes default "user" from VF2 boards
    └── flash-sd.sh           → SD card flashing utility

nodes/                        → Node-specific provisioning scripts
├── databrokers/              → Data Broker nodes
│   ├── hifive-p550/          → SiFive HiFive Premier P550
│   │   └── forge-brakerbox-p550.sh  → P550 Data Broker provisioning engine
│   ├── milkv-titan/          → Milk-V Titan
│   │   └── forge-brakerbox-titan.sh  → Titan Data Broker provisioning engine
│   └── starfive-vf2/         → StarFive VisionFive2
│       └── forge-brakerbox-vf2.sh   → VF2 Data Broker provisioning engine
└── inference/                → Inference nodes
    └── starfive-vf2-hailo8/  → StarFive VisionFive2 + Hailo-8(L)
        └── forge-visionferret-h8.sh  → Unified Hailo-8 & RISC-V provisioning engine
~~~
