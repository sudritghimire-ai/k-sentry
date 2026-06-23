# TimeFence Collector Resource Summary

duration_sec=20
stress_iterations=5000
samples=20
sampled_comm=timefence-epbf

| Metric | Mean | Min | Max | Stddev |
|---|---:|---:|---:|---:|
| CPU % | 0.3550 | 0.1000 | 1.4000 | 0.3170 |
| RSS KB | 17776.00 | 17776.00 | 17776.00 | 0.00 |
| VSZ KB | 20540.00 | 20540.00 | 20540.00 | 0.00 |

Collector report fields:

- kept_events=not_available_killed_before_normal_exit
- filtered_events=not_available_killed_before_normal_exit
- final_digest=not_available_killed_before_normal_exit

Interpretation:

This measures the actual timefence-epbf userspace collector process while a stress workload generates exec/open/connect events. If the collector is killed at the end of the sampling window, kept/skipped/digest may be unavailable because the normal report footer is only written on clean exit.
