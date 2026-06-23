# TimeFence Final Evaluation Table

| Evaluation area | Artifact file(s) | Main result | Interpretation |
|---|---|---|---|
| Baseline throughput | `baseline_bench_summary.csv`, `baseline_throughput.png` | K-Sentry triangular: ~176.3M events/sec | K-Sentry is slower than affine rolling hash but faster than HMAC-SHA256, BLAKE3, and Merkle chunk baselines in the scalar-event benchmark. |
| HMAC baseline | `baseline_bench_summary.csv` | HMAC-SHA256: ~140.4M events/sec | K-Sentry was ~1.26× faster than HMAC-SHA256 batch in this benchmark. |
| BLAKE3 baseline | `baseline_bench_summary.csv` | BLAKE3: ~65.5M events/sec | K-Sentry was ~2.7× faster than BLAKE3 batch in this benchmark. |
| Merkle baseline | `baseline_bench_summary.csv` | Merkle chunks: ~65.5M events/sec | K-Sentry was ~2.7× faster than Merkle chunk hashing in this benchmark. |
| Workload runtime overhead | `overhead_file_read_summary.csv` | 0.86% runtime overhead | eBPF collector caused low observable overhead on a 10-run, 5000-iteration file-read workload. |
| CPU/memory workload overhead | `resource_overhead_summary.md` | 0.7593% runtime overhead, no CPU/RSS delta for workload process | File-read workload resource usage was nearly unchanged with collector running. |
| Collector process resources | `collector_resource_summary.md` | 0.45% mean CPU, 1.9% max CPU, ~17.4 MB RSS | Actual `timefence-epbf` collector process used low CPU and modest memory during stress. |
| Detection latency | `detection_latency_summary.csv` | ~348.45 ms mean end-to-end 3-case runtime | Real-trace verification completed the full strace ingestion and verification workflow in ~0.35 sec. |
| Strace real-ingestion | `timefence_trace_3case_report.txt` | CLEAN, METADATA_MISMATCH_LENGTH, DIGEST_MISMATCH_SAME_LENGTH | TimeFence detects clean traces, extra/missing events, and same-length changes on real Linux syscall traces. |
| eBPF live telemetry | `timefence_ebpf_exec_openat_connect_report.txt` | execve/openat/connect → K-Sentry digest | Live Linux kernel telemetry is folded into TimeFence evidence through eBPF ring buffer. |
| Connect IP:port decoding | `timefence_ebpf_ip_port_report.txt` | Example: `Connect:curl:34.223.124.45:80` | IPv4 connect destinations are decoded from sockaddr and included in telemetry evidence. |
| Overload/stress | `overload_report.txt` | kept_events=120, filtered_events=2293 | Under stress, TimeFence continues producing evidence but skips many events, motivating kernel-side filtering/backpressure work. |
| Real workload | `real_workload_report.txt` | kept_events=24, filtered_events=648 | TimeFence captured a mixed Python HTTP + file read + curl workload. |

## One-sentence evaluation takeaway

TimeFence combines a verified streaming accumulator with real Linux telemetry ingestion, achieving high scalar-event throughput, low measured eBPF overhead, live exec/open/connect evidence, and detection of both missing/extra events and same-length trace changes.

## Main limitations

1. IPv4 connect decoding works, but IPv6 is not decoded yet.
2. Userspace filtering causes many skipped events under stress.
3. Linux/eBPF ingestion is tested and demonstrated but not formally verified.
4. More real workloads and ring-buffer/backpressure sweeps are needed for a full systems-paper evaluation.

## TimeFence vs baseline workload comparison

| Workload | Runs | Baseline mean ms | TimeFence mean ms | Overhead |
|---|---:|---:|---:|---:|
| file/network comparison workload | 10 | 2787.6804 | 2925.9422 | 4.9597% |

This compares the same workload with no monitor versus the TimeFence eBPF collector running in WSL.
