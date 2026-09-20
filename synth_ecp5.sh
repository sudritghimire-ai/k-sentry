#!/usr/bin/env bash
set -euo pipefail
RTL=${1:-mersennefence_v2.sv}
TOP=${2:-mersenne_guard_bench}
FREQ=${3:-200}
SEED=${4:-1}
mkdir -p build/${TOP}_${FREQ}_${SEED}
D=build/${TOP}_${FREQ}_${SEED}
yosys -ql "$D/yosys.log" -p "read_verilog -sv $RTL; synth_ecp5 -nodsp -top $TOP -json $D/$TOP.json; stat"
nextpnr-ecp5 --85k --package CABGA381 --speed 8 --json "$D/$TOP.json" --textcfg "$D/$TOP.config" --freq "$FREQ" --seed "$SEED" --lpf-allow-unconstrained --report "$D/report.json" 2>&1 | tee "$D/nextpnr.log"
