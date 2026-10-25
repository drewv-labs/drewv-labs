<div align="center">

![DREW-V Labs](https://github.com/drewv-labs/drewv-labs-toolkit/blob/main/.github/images/drewv-labs-github-banner.png)  

# RISC-V Edge Toolkit

</div>

## About  

**DREW-V Labs** is focused on the development of a RISC-V based Edge ML and Data Brokering R&D. This toolkit is designed to be used with a variety of hardware and software types, and is designed to be easily integrated into existing edge computing environments. We leverage Apple Silicon & Debian based development machines and favor Golang, Rust, & Python based languages to build robust light-but-mighty solutions to unleash the full power of RISC-V technology for the open edge science & engineering frontier.

---

## Kit File Structure

~~~text
lildebbyhelpers/                → Core Debian Helpers
├── harden.sh                   → Removes default "user" from VF2 boards
└── pregame.sh                  → Updates <user> and <hostname> from default

nodes/                          → Node-specific provisioning scripts
├── sifive-p550-databroker/     → SiFive HiFive Premier P550 Data Broker
│   ├── flash-sd.sh             → SD card flashing utility
│   ├── deploy-forge.sh         → Pushes toolkit to remote nodes
│   └── forge/
│       └── forge-brakerbox-p550.sh  → Unified P550 Data Broker provisioning engine
├── starfive-vf2-databroker/    → StarFive VisionFive2 Databroker
│   ├── flash-sd.sh             → SD card flashing utility
│   ├── deploy-forge.sh         → Pushes toolkit to remote nodes
│   └── forge/
│       └── forge-brakerbench-vf2.sh  → Unified VF2 Databroker provisioning engine
└── starfive-vf2-hailo-ai/      → StarFive VisionFive2 + Hailo-8(L) Inference Engine
    ├── flash-sd.sh             → SD card flashing utility
    ├── deploy-forge.sh         → Pushes toolkit to remote nodes
    └── forge/
        └── forge-visionferret-h8.sh  → Unified Hailo-8 & RISC-V provisioning engine
~~~
