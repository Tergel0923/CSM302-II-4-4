#!/usr/bin/env bash
# Run on the Ubuntu VM (repo root). Collects the live-kernel evidence the peer review asked for into docs/evidence/live/.
# Usage: bash tools/collect_kernel_evidence.sh
set -u
OUT=docs/evidence/live; mkdir -p "$OUT"
{ date -Is; uname -a; gcc --version | head -1; python3 --version; ls -d /lib/modules/$(uname -r)/build; } > "$OUT/environment.txt" 2>&1
make clean >/dev/null 2>&1; make kernel > "$OUT/make-kernel.txt" 2>&1 || { echo "BUILD FAILED, see $OUT/make-kernel.txt"; exit 1; }
sudo rmmod collatz colors 2>/dev/null
sudo dmesg -C
sudo insmod src/kernel/colors.ko && sudo insmod src/kernel/collatz.ko start=15 || { echo "insmod failed; see dmesg"; sudo dmesg | tail -20; exit 1; }
{ echo '--- /proc/kds_colors'; sudo cat /proc/kds_colors; echo; echo '--- /proc/kds_collatz'; sudo cat /proc/kds_collatz; } > "$OUT/proc-after-load.txt"
printf 'ADD 10 20 30\n' | sudo tee /proc/kds_colors >/dev/null; printf 'SEARCH 10 20 30\n' | sudo tee /proc/kds_colors >/dev/null
sudo cat /proc/kds_colors > "$OUT/proc-after-add-search.txt"
sudo dmesg | grep -E 'kds_colors|kds_collatz' > "$OUT/dmesg-load.txt"
sudo rmmod collatz; sudo rmmod colors
sudo dmesg | grep -E 'kds_colors|kds_collatz' > "$OUT/dmesg-unload.txt"
ls /proc/kds_colors /proc/kds_collatz > "$OUT/proc-after-unload.txt" 2>&1   # must report 'No such file'
sudo python3 tests/kernel_acceptance.py 2>&1 | tee "$OUT/kernel-acceptance.txt"
echo "Done. Take live UI screenshots (sudo python3 src/ui/server.py --mode kernel) into docs/screenshots/live-*.png and commit docs/evidence/live/."
