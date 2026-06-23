Next, safely recreate the artifact summary file using a full command.

Run:

````bash
cd ~/k-sentry

cat > ARTIFACT_SUMMARY.md <<'EOF'
# TimeFence Artifact Summary

## One-command local artifact

Run:

```bash
./scripts/run_all_local.sh
````

Produces:

| Artifact                                     | What it shows                                                                                 |
| -------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `artifacts/timefence_report.json`            | Local TimeFence evidence reports for clean, drop, swap, duplicate, truncate, and splice cases |
| `artifacts/bench.csv`                        | Local K-Sentry throughput benchmark                                                           |
| `artifacts/baseline_bench.csv`               | Single-run baseline comparison                                                                |
| `artifacts/baseline_bench_repeated.csv`      | Repeated benchmark runs                                                                       |
| `artifacts/baseline_bench_summary.csv`       | Mean/min/max/stddev baseline summary                                                          |
| `artifacts/baseline_throughput.png`          | Baseline throughput graph                                                                     |
| `artifacts/timefence_trace_3case_report.txt` | Real Linux strace ingestion: clean, length mismatch, same-length digest mismatch              |

## eBPF live artifact

Run:

```bash
./scripts/run_ebpf_live.sh
```

In another terminal:

```bash
echo secret-token >/tmp/timefence_live.txt
cat /tmp/timefence_live.txt
cat /etc/hostname
curl -I http://example.com
```

Produces:

| Artifact                                                  | What it shows                                                          |
| --------------------------------------------------------- | ---------------------------------------------------------------------- |
| `artifacts/timefence_ebpf_exec_openat_connect_report.txt` | Live eBPF telemetry over execve, openat, connect, folded into K-Sentry |

## Current baseline summary

The repeated benchmark compares:

* K-Sentry triangular accumulator
* affine rolling hash
* HMAC-SHA256 batch
* BLAKE3 batch
* Merkle chunks

Main figure:

```text
artifacts/baseline_throughput.png
```

## Main claim supported by artifact

TimeFence demonstrates a verified, order-sensitive streaming accumulator connected to real Linux telemetry:

```text
Verus proof
→ Rust timefence-core
→ strace real-ingestion demo
→ eBPF exec/open/connect live ingestion
→ K-Sentry digest/checkpoint
→ artifact reports and baseline graph
```

## Current limitations

* Connect events currently record `socket_connect`, not decoded IP:port.
* eBPF filtering is currently done in userspace.
* Linux ingestion code is tested and demonstrated, but not formally verified.
* Evaluation still needs CPU overhead, memory overhead, overload/drop behavior, and real workload traces.
  EOF

````
