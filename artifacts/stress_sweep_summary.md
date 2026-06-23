# TimeFence Stress Sweep Summary

This sweep varies the stress workload size and records kept events, filtered events, and digest outputs.

Important: `filtered_events` means userspace policy-filtered events, not proven ring-buffer output failures. `ringbuf_output_failures` is currently not measured.

| Stress iterations | Duration ms | Kept events | Filtered events | Ringbuf drops | Final digest |
|---:|---:|---:|---:|---|---:|
| 500 | 2117.03 | 30 | 405 | not_measured | 558645793 |
| 1000 | 3518.13 | 28 | 635 | not_measured | 480646805 |
| 2000 | 8661.01 | 30 | 436 | not_measured | 570798470 |

## Interpretation

The stress sweep shows how the current prototype behaves as event pressure increases. Kept events are the events admitted into TimeFence evidence. Filtered events are events observed but ignored by the userspace policy. Ring-buffer drops are not yet measured and should be added in a future kernel-side accounting experiment.
