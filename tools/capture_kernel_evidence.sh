#!/usr/bin/env bash
# Capture genuine kernel-module evidence on the currently booted native Ubuntu kernel.
# Run from the repository root: sudo bash tools/capture_kernel_evidence.sh
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
OUT="$ROOT/docs/evidence/kernel-runtime.txt"
mkdir -p "$(dirname "$OUT")"
exec > >(tee "$OUT") 2>&1

loaded_colors=0
loaded_collatz=0
cleanup() {
  set +e
  if (( loaded_collatz )); then rmmod collatz; loaded_collatz=0; fi
  if (( loaded_colors )); then rmmod colors; loaded_colors=0; fi
}
trap cleanup EXIT

echo "=== II-4-4 genuine kernel runtime evidence ==="
date --iso-8601=seconds
echo "User: $(id -un) (uid=$(id -u))"
echo "Kernel: $(uname -a)"
echo "Distribution: $(. /etc/os-release && echo "$PRETTY_NAME")"
echo "Kernel release: $(uname -r)"

if (( EUID != 0 )); then echo "ERROR: run with sudo."; exit 1; fi
if grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease; then
  echo "ERROR: WSL detected. Boot native Ubuntu; kernel module loading here is not accepted as host evidence."
  exit 1
fi
if [[ ! -e "/lib/modules/$(uname -r)/build/Makefile" ]]; then
  echo "ERROR: matching kernel headers are missing."
  echo "Install with: apt update && apt install -y build-essential linux-headers-$(uname -r)"
  exit 1
fi
if [[ -e /sys/module/colors || -e /sys/module/collatz ]]; then
  echo "ERROR: colors or collatz module is already loaded. Nothing was unloaded; resolve the existing module first."
  lsmod | grep -E '^(colors|collatz)\b' || true
  exit 1
fi

echo
echo "=== Build modules for the running kernel ==="
make -C src/kernel clean
make -C src/kernel W=1
test -s src/kernel/colors.ko
test -s src/kernel/collatz.ko

echo
echo "=== Load colors module and verify /proc interface ==="
insmod src/kernel/colors.ko
loaded_colors=1
test -r /proc/kds_colors
cat /proc/kds_colors
echo "ADD 10 20 30" > /proc/kds_colors
echo "After ADD 10 20 30:"
cat /proc/kds_colors
echo "SEARCH 10 20 30" > /proc/kds_colors
echo "After SEARCH 10 20 30:"
cat /proc/kds_colors
echo "DELETE 5" > /proc/kds_colors
echo "After DELETE 5:"
cat /proc/kds_colors
echo "CLEAR" > /proc/kds_colors
echo "After CLEAR (empty list expected):"
cat /proc/kds_colors
echo "RESET" > /proc/kds_colors
echo "After RESET (four nodes expected):"
cat /proc/kds_colors
rmmod colors
loaded_colors=0
test ! -e /proc/kds_colors
echo "PASS: colors module unloaded and /proc/kds_colors removed."

echo
echo "=== Load Collatz module with start=15 ==="
insmod src/kernel/collatz.ko start=15
loaded_collatz=1
test -r /proc/kds_collatz
cat /proc/kds_collatz
echo "Expected sequence: 15 46 23 70 35 106 53 160 80 40 20 10 5 16 8 4 2 1"
rmmod collatz
loaded_collatz=0
test ! -e /proc/kds_collatz
echo "PASS: collatz module unloaded and /proc/kds_collatz removed."

echo
echo "=== Kernel log evidence (module init/exit records) ==="
dmesg --color=never | grep -E 'kds_colors:|kds_collatz:' | tail -n 100 || true
echo
echo "=== Loaded-module check ==="
if lsmod | grep -E '^(colors|collatz)\b'; then
  echo "ERROR: module still appears loaded."
  exit 1
else
  echo "PASS: neither project module remains loaded."
fi

echo
echo "PASS: live kernel build, insmod, /proc reads/writes, rmmod, and dmesg capture completed."
echo "Evidence saved to: docs/evidence/kernel-runtime.txt"
