SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRAKERRAK_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
TOOLKIT_ROOT="${TOOLKIT_ROOT:-$(cd "${BRAKERRAK_ROOT}/../riscv-toolkit" && pwd)}"
SNAP_DIR="${SCRIPT_DIR}/snapshots"

echo ">>> [STAGE 0A] Running Ubuntu & SiFive P550 BSP Day-0 Bootstraps..."
sudo "${TOOLKIT_ROOT}/bootstrap-ubuntu.sh" --user drew --hostname brakerbox-p550 --nopasswd
sudo "${TOOLKIT_ROOT}/sifive/hifive-premier-p550/bootstrap.sh"
