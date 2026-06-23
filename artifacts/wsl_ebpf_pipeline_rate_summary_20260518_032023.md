# TimeFence eBPF Pipeline Throughput Summary

This measures the end-to-end live telemetry pipeline: Linux syscall tracepoints -> eBPF ring buffer -> userspace collector -> filtering -> TelemetryEvent -> field element -> K-Sentry update.

Important:  means userspace policy-filtered events. It does not mean ring-buffer output failures.  is currently not measured by the prototype.

| Stress iterations | Duration ms | Kept events | Filtered events | Total observed | Observed events/sec | Kept events/sec | Ringbuf drops | Final digest |
|---:|---:|---:|---:|---:|---:|---:|---|---:|
| 500 | 2212.09 | 49 | 1038 | 1087 | 491.39 | 22.15 | not_measured | 527858609 |
| 1000 | 4330.23 | 73 | 1275 | 1348 | 311.30 | 16.86 | not_measured | 330559046 |
| 2000 | 8782.03 | 126 | 2680 | 2806 | 319.52 | 14.35 | not_measured | 649376726 |

## Interpretation

This experiment is stronger than scalar accumulator throughput because it measures the live eBPF ingestion path. The current prototype still does not measure actual ring-buffer output failures, so these results should be interpreted as observed userspace pipeline rate rather than loss-free kernel event throughput.
