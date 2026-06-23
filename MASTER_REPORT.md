# TimeFence Master Report

## Project status

TimeFence is a verified order-sensitive streaming evidence system for Linux telemetry.

Pipeline:

Verus proof
-> Rust timefence-core
-> strace real-ingestion
-> eBPF exec/open/connect telemetry
-> IPv4 connect IP:port decoding
-> K-Sentry live digest
-> evidence reports
-> throughput/overhead/stress/real workload evaluation

## Main artifacts

### Verified/core
- proofs / Verus artifact
- timefence-core/
- artifacts/timefence_report.json

### Real strace ingestion
- artifacts/timefence_trace_3case_report.txt
- artifacts/detection_latency.csv
- artifacts/detection_latency_summary.csv

### eBPF live telemetry
- artifacts/timefence_ebpf_exec_openat_connect_report.txt
- artifacts/timefence_ebpf_filtered_report_v2.txt
- artifacts/timefence_ebpf_ip_port_report.txt

### Baselines
- artifacts/baseline_bench.csv
- artifacts/baseline_bench_repeated.csv
- artifacts/baseline_bench_summary.csv
- artifacts/baseline_throughput.png

### Runtime/resource overhead
- artifacts/overhead_file_read.csv
- artifacts/overhead_file_read_summary.csv
- artifacts/resource_overhead.csv
- artifacts/resource_overhead_summary.md
- artifacts/collector_resource.csv
- artifacts/collector_resource_summary.md

### Stress and pipeline rate
- artifacts/stress_sweep.csv
- artifacts/stress_sweep_summary.md
- artifacts/ebpf_pipeline_rate.csv
- artifacts/ebpf_pipeline_rate_summary.md

### Real workload
- artifacts/real_workload_report.txt
- artifacts/real_workload_raw_ebpf_report.txt

### Summary files
- artifacts/evaluation_summary.md
- artifacts/final_evaluation_table.md
- paper_evaluation_section.md

## Key results

### Baseline throughput

10-run synthetic scalar benchmark over 1,000,000 events:

- Rolling hash affine: ~237.6M events/sec
- K-Sentry triangular: ~176.3M events/sec
- HMAC-SHA256 batch: ~140.4M events/sec
- BLAKE3 batch: ~65.5M events/sec
- Merkle chunks: ~65.5M events/sec

### eBPF pipeline rate

WSL end-to-end live pipeline:

- N=500: ~493.6 observed events/sec
- N=1000: ~398.2 observed events/sec
- N=2000: ~277.2 observed events/sec

This includes syscall tracepoints, eBPF ring buffer, userspace collector, filtering, TelemetryEvent creation, field-element mapping, and K-Sentry update.

### Runtime overhead

10-run, 5000-iteration file-read workload:

- No collector: 10915.50 ms
- With eBPF collector: 11009.51 ms
- Runtime overhead: 0.86%

### Workload CPU/memory overhead

5-run, 5000-iteration file-read workload:

- Runtime overhead: 0.7593%
- CPU percent delta: 0.0000
- Max RSS delta: 0 KB

### Collector process resource usage

20-second stress workload:

- sampled process: timefence-epbf
- mean CPU: 0.4476%
- max CPU: 1.9000%
- RSS: 17,776 KB

### Detection latency

10-run full strace 3-case workflow:

- mean runtime: 348.45 ms
- min: 340.01 ms
- max: 358.41 ms
- stddev: 6.51 ms

### Real strace cases

- clean_vs_clean -> CLEAN
- clean_vs_extra_overwrite -> METADATA_MISMATCH_LENGTH
- clean_vs_same_length_change -> DIGEST_MISMATCH_SAME_LENGTH

### Real workload

Python HTTP server + file reads + localhost curl + external curl:

- kept_events=24
- filtered_events=648
- final_digest=795125924

### Connect IP:port

IPv4 connect decoding works.

Example:

Connect:curl:34.223.124.45:80

## Important terminology

filtered_events means userspace policy-filtered events.

It does not mean ring-buffer dropped events.

ringbuf_output_failures is reported by the eBPF accounting path when available; in WSL it may appear as not_available_map_not_found.

## Current limitations

1. Most evaluation is WSL prototype evaluation.
2. Native Linux/cloud VM rerun is needed before ATC submission.
3. ringbuf_output_failures is not measured yet.
4. IPv6 connect decoding is not implemented.
5. Some filtering is userspace-side.
6. More real workloads are needed.
7. Linux/eBPF ingestion is tested but not formally verified.

## ATC next work

1. Native Linux/cloud rerun
2. Actual ring-buffer drop accounting
3. Larger real workloads
4. Comparison with auditd/Falco/Tetragon/OpenTelemetry
5. Strong threat model
6. Paper polish with mentor/coauthor feedback

## TimeFence vs baseline comparison workload

A 10-run WSL comparison workload measured the same file/network workload with no monitor and with the TimeFence eBPF collector running.

Results:

- baseline_no_monitor mean: 2787.6804 ms
- timefence_collector mean: 2925.9422 ms
- TimeFence overhead: 4.9597%

Interpretation:

On this WSL comparison workload, TimeFence added about 5% mean runtime overhead. This is a prototype WSL measurement; native Linux/cloud reruns are still needed for ATC-grade overhead claims.
