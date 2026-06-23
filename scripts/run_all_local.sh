#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/k-sentry"
ARTIFACTS="$ROOT/artifacts"

echo "=== TimeFence Full Local Artifact Runner ==="

mkdir -p "$ARTIFACTS"

echo
echo "[1/4] Running Verus proof artifact..."
cd "$ROOT/verus-x86-win"

if [ -f "./verus.exe" ]; then
    ./verus.exe ../proofs/finaltest_timefence_core_verified.rs
else
    echo "Skipping Verus: verus.exe not found in $ROOT/verus-x86-win"
fi

echo
echo "[2/4] Running timefence-core tests..."
cd "$ROOT/timefence-core"
cargo test

echo
echo "[3/4] Running timefence-core release demo..."
cargo run --release

echo
echo "[4/4] Running strace real-ingestion 3-case demo..."
cd "$ROOT/timefence-trace"
cargo run --release

echo
echo "Copying reports to artifacts/..."

if [ -f "$ROOT/timefence-core/timefence_report.json" ]; then
    cp "$ROOT/timefence-core/timefence_report.json" "$ARTIFACTS/timefence_report.json"
fi

if [ -f "$ROOT/timefence-core/artifacts/bench.csv" ]; then
    cp "$ROOT/timefence-core/artifacts/bench.csv" "$ARTIFACTS/bench.csv"
fi

if [ -f "$ROOT/timefence-trace/timefence_trace_3case_report.txt" ]; then
    cp "$ROOT/timefence-trace/timefence_trace_3case_report.txt" "$ARTIFACTS/timefence_trace_3case_report.txt"
fi

if [ -f "$ROOT/timefence-epbf/timefence_ebpf_filtered_report.txt" ]; then
    cp "$ROOT/timefence-epbf/timefence_ebpf_filtered_report.txt" "$ARTIFACTS/timefence_ebpf_exec_openat_connect_report.txt"
fi

echo
echo "=== Done ==="
echo "Artifacts:"
ls -lh "$ARTIFACTS"

# Copy baseline benchmark CSV
if [ -f "$ROOT/timefence-core/artifacts/baseline_bench.csv" ]; then
    cp "$ROOT/timefence-core/artifacts/baseline_bench.csv" "$ARTIFACTS/baseline_bench.csv"
fi
if [ -f "$ROOT/timefence-core/artifacts/baseline_bench_repeated.csv" ]; then
    cp "$ROOT/timefence-core/artifacts/baseline_bench_repeated.csv" "$ARTIFACTS/baseline_bench_repeated.csv"
fi

if [ -f "$ROOT/timefence-core/artifacts/baseline_bench_summary.csv" ]; then
    cp "$ROOT/timefence-core/artifacts/baseline_bench_summary.csv" "$ARTIFACTS/baseline_bench_summary.csv"
fi
echo "=== Done ==="
echo
echo "Generating benchmark graph..."
if command -v python3 >/dev/null 2>&1; then
    python3 "$ROOT/scripts/plot_baselines.py" || echo "Warning: graph generation failed"
else
    echo "Warning: python3 not found; skipping graph generation"
fi
ls -lh "$ARTIFACTS"