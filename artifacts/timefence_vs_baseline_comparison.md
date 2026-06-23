# TimeFence vs Baseline Workload Comparison

runs=10
iterations=1000

| Mode | Mean duration ms | Stddev ms |
|---|---:|---:|
| baseline_no_monitor | 2787.6804 | 275.8227 |
| timefence_collector | 2925.9422 | 583.2133 |

timefence_overhead_percent=4.9597

This compares the same file/network workload with no monitor versus the TimeFence eBPF collector running.
