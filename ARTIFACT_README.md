# TimeFence Artifact README

TimeFence is a verified order-sensitive streaming evidence system for Linux telemetry.

This artifact contains:

- Verus-verified K-Sentry accumulator core
- Rust `timefence-core` library
- Real strace ingestion demo
- eBPF ring-buffer collector for `execve`, `openat`, and `connect`
- IPv4 connect IP:port decoding
- Baseline benchmarks
- Overhead/resource measurements
- Stress and pipeline-rate experiments
- Real workload evidence reports

---

## 1. Repository layout

| Path | Purpose |
|---|---|
| `proofs/` | Verus proof artifact |
| `timefence-core/` | Rust core library, verifier, incident reports, baseline benchmarks |
| `timefence-trace/` | strace real-ingestion prototype |
| `timefence-epbf/` | eBPF ring-buffer collector |
| `scripts/` | experiment runners |
| `artifacts/` | generated reports, CSVs, graphs, summaries |

---

## 2. Main one-command local artifact

Run:

```bash
cd ~/k-sentry
./scripts/run_all_local.sh
