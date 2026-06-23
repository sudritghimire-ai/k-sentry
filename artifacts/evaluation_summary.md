# TimeFence Evaluation Summary

## 1. Baseline throughput

Source files:
- artifacts/baseline_bench_summary.csv
- artifacts/baseline_throughput.png

10-run synthetic scalar-event benchmark over 1,000,000 events:

| Method | Mean throughput |
|---|---:|
| Rolling hash affine | ~237.6M events/sec |
| K-Sentry triangular | ~176.3M events/sec |
| HMAC-SHA256 batch | ~140.4M events/sec |
| Merkle chunks | ~65.5M events/sec |
| BLAKE3 batch | ~65.5M events/sec |

Interpretation:

K-Sentry is slower than affine rolling hash, but faster than HMAC-SHA256, BLAKE3, and Merkle chunk baselines in this synthetic scalar-event benchmark.

---

## 2. eBPF overhead

Source files:
- artifacts/overhead_file_read.csv
- artifacts/overhead_file_read_summary.csv

10 runs, 5000-iteration file-read workload:

| Mode | Mean runtime |
|---|---:|
| No collector | 10915.50 ms |
| With eBPF collector | 11009.51 ms |

Measured overhead: 0.86%

Interpretation:

The eBPF collector added low overhead on this file-read workload.

---

## 3. Overload/stress experiment

Source files:
- artifacts/overload_report.txt
- artifacts/overload_raw_ebpf_report.txt

Stress workload:
- stress_iterations=2000
- tracepoints=execve,openat,connect

Result:
- kept_events=120
- filtered_events=2293
- final_digest=980930368

Interpretation:

Under stress, TimeFence continued producing ordered K-Sentry evidence, but the prototype skipped many events. This motivates kernel-side filtering, backpressure accounting, and larger ring-buffer experiments.

---

## 4. Real workload experiment

Source files:
- artifacts/real_workload_report.txt
- artifacts/real_workload_raw_ebpf_report.txt

Workload:
- Python HTTP server
- local file reads
- localhost curl requests
- external curl request

Result:
- kept_events=24
- filtered_events=648
- final_digest=795125924

Observed event examples:
- OpenFile:/tmp/timefence_real_workload/secret.txt
- OpenFile:/etc/passwd
- Connect:socket_connect_non_ipv4
- Exec:bash

Interpretation:

TimeFence captured a mixed workload involving process execution, file access, and network activity, then folded those events into a live K-Sentry digest.

---

## 5. Real strace ingestion

Source file:
- artifacts/timefence_trace_3case_report.txt

Cases:

| Case | Result |
|---|---|
| clean_vs_clean | CLEAN |
| clean_vs_extra_overwrite | METADATA_MISMATCH_LENGTH |
| clean_vs_same_length_change | DIGEST_MISMATCH_SAME_LENGTH |

Interpretation:

TimeFence detects both extra/missing events and same-length trace changes on real Linux syscall traces.

---

## 6. Live eBPF evidence

Source file:
- artifacts/timefence_ebpf_exec_openat_connect_report.txt

Live path:

execve/openat/connect tracepoints
-> eBPF ring buffer
-> Rust userspace
-> TelemetryEvent
-> field element
-> K-Sentry digest
-> evidence report

---

## 7. Connect IP:port decoding

Source file:
- artifacts/timefence_ebpf_ip_port_report.txt

The eBPF connect parser can decode IPv4 sockaddr destinations.

Example:
- Connect:curl:34.223.124.45:80

Current limitation:
- IPv6/non-IPv4 addresses are reported as socket_connect_non_ipv4.

---

## 8. Current limitations

1. IPv4 connect decoding works, but IPv6 is not decoded yet.
2. Some filtering is done in userspace instead of inside eBPF.
3. Linux ingestion/eBPF code is tested and demonstrated but not formally verified.
4. Overload behavior needs deeper experiments with ring-buffer sizes and event rates.
5. Real workload evaluation should be expanded beyond the current Python HTTP workload.

---

## 9. Next evaluation steps

1. Add IPv6 connect decoding.
2. Add ring-buffer size sweep.
3. Add CPU/memory overhead under multiple workloads.
4. Add detection-latency experiment.
5. Add larger real workloads: build workload, package install, local web server, Python script workload.
6. Write paper evaluation section.

---

## 10. End-to-end real-trace detection latency

Source files:
- artifacts/detection_latency.csv
- artifacts/detection_latency_summary.csv

Experiment:

10 runs of the full strace 3-case real-ingestion verifier.

Cases:
- clean_vs_clean
- clean_vs_extra_overwrite
- clean_vs_same_length_change

Result:

| Metric | Value |
|---|---:|
| Mean full 3-case runtime | 348.45 ms |
| Minimum runtime | 340.01 ms |
| Maximum runtime | 358.41 ms |
| Standard deviation | 6.51 ms |

Interpretation:

This measures end-to-end real-trace verification latency, not only digest comparison. It includes spawning traced commands, parsing strace output, converting raw syscall lines into TelemetryEvent records, computing K-Sentry digests, and verifying clean, length-mismatch, and same-length digest-mismatch cases.

Main result:

TimeFence completed the full real-trace 3-case verification workflow in about 0.35 seconds on average.

---

## 11. CPU and memory overhead

Source files:
- artifacts/resource_overhead.csv
- artifacts/resource_overhead_summary.md

Experiment:

5 runs of a 5000-iteration file-read workload.

Result:

| Mode | Mean elapsed sec | Mean CPU % | Mean max RSS KB |
|---|---:|---:|---:|
| No collector | 10.8000 | 52.60 | 3584 |
| With eBPF collector | 10.8820 | 52.60 | 3584 |

Summary:

- Runtime overhead: 0.7593%
- CPU percent delta: 0.0000
- Max RSS delta: 0 KB

Interpretation:

TimeFence’s eBPF collector added less than 1% mean runtime overhead on this file-read workload, with no measured change in workload CPU percentage or maximum resident memory. This measures the workload process resource usage; future evaluation should separately measure the collector process resource usage.

---

## 12. Collector process CPU and memory usage

Source files:
- artifacts/collector_resource.csv
- artifacts/collector_resource_summary.md
- artifacts/collector_resource_collector.log
- artifacts/collector_resource_stress.log

Experiment:

The eBPF userspace collector was sampled for 20 seconds while a stress workload generated exec/open/connect events.

Result:

| Metric | Value |
|---|---:|
| Samples | 21 |
| Sampled process | timefence-epbf |
| Mean CPU | 0.4476% |
| Max CPU | 1.9000% |
| Mean RSS | 17,776 KB |
| Mean VSZ | 20,540 KB |

Interpretation:

During a 20-second stress workload, the TimeFence userspace collector used 0.45% mean CPU, peaked at 1.9% CPU, and held about 17.4 MB RSS. This measures the actual timefence-epbf collector process, not the sudo wrapper.

Note:

The collector was killed at the end of the sampling window, so kept_events, filtered_events, and final_digest were not available from this resource experiment. Event-count behavior is instead measured in the overload/stress experiment.

---

## 12. Collector process CPU and memory usage

Source files:
- artifacts/collector_resource.csv
- artifacts/collector_resource_summary.md
- artifacts/collector_resource_collector.log
- artifacts/collector_resource_stress.log

Experiment:

The eBPF userspace collector was sampled for 20 seconds while a stress workload generated exec/open/connect events.

Result:

| Metric | Value |
|---|---:|
| Samples | 21 |
| Sampled process | timefence-epbf |
| Mean CPU | 0.4476% |
| Max CPU | 1.9000% |
| Mean RSS | 17,776 KB |
| Mean VSZ | 20,540 KB |

Interpretation:

During a 20-second stress workload, the TimeFence userspace collector used 0.45% mean CPU, peaked at 1.9% CPU, and held about 17.4 MB RSS. This measures the actual timefence-epbf collector process, not the sudo wrapper.

Note:

The collector was killed at the end of the sampling window, so kept_events, filtered_events, and final_digest were not available from this resource experiment. Event-count behavior is instead measured in the overload/stress experiment.
