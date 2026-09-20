# MersenneFence synthesis target

Goal: compare a 64-bit sequence ordering comparator with an exact CRT guard and a merged sequence+semantic detector.

Target used by CI: Lattice ECP5-85F speed grade 8, CABGA381, via Yosys + nextpnr-ecp5. This is an open-source reproducible timing target, not the final HFT deployment FPGA.

The CI sweeps 200 MHz (5.000 ns), 222 MHz (4.505 ns), and 250 MHz (4.000 ns), five placement seeds each, for:

- `seq64_order_bench`: 64-bit baseline equality/ordering comparison.
- `mersenne_guard_bench`: full 64-bit input -> exact Mersenne CRT guard.
- `mersenne_guard_predecoded_bench`: residue formation overlapped with parser; narrow post-parser critical path only.
- `mersennefence_merged_bench`: full guard plus 17 parallel PacketFence semantic byte lanes.

Mathematical sequence representation:

- mod 4096
- mod 2047 = 2^11-1
- mod 8191 = 2^13-1
- mod 16383 = 2^14-1
- mod 32767 = 2^15-1

Their product exceeds 2^64 and the moduli are pairwise coprime, so the tuple is injective on 64-bit sequence values.

Fast-path offset window is [-2047, 2047]. A 64-bit serial wrap is routed to slow path.

Timing interpretation:

- <= 5.0 ns means >= 200 MHz
- <= 4.5 ns means >= 222 MHz
- <= 4.0 ns means >= 250 MHz
