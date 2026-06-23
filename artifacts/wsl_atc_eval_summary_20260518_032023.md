# TimeFence Native/Cloud ATC Evaluation Summary

timestamp=20260518_032023

## Machine information

```text
Linux sudritghimire 6.6.87.2-microsoft-standard-WSL2 #1 SMP PREEMPT_DYNAMIC Thu Jun  5 18:30:46 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux

Architecture:                         x86_64
CPU op-mode(s):                       32-bit, 64-bit
Address sizes:                        48 bits physical, 48 bits virtual
Byte Order:                           Little Endian
CPU(s):                               32
On-line CPU(s) list:                  0-31
Vendor ID:                            AuthenticAMD
Model name:                           AMD Ryzen 9 8940HX with Radeon Graphics
CPU family:                           25
Model:                                97
Thread(s) per core:                   2
Core(s) per socket:                   16
Socket(s):                            1
Stepping:                             2
BogoMIPS:                             4790.89
Flags:                                fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ht syscall nx mmxext fxsr_opt pdpe1gb rdtscp lm constant_tsc rep_good nopl tsc_reliable nonstop_tsc cpuid extd_apicid tsc_known_freq pni pclmulqdq ssse3 fma cx16 sse4_1 sse4_2 movbe popcnt aes xsave avx f16c rdrand hypervisor lahf_lm cmp_legacy svm cr8_legacy abm sse4a misalignsse 3dnowprefetch osvw topoext perfctr_core ssbd ibrs ibpb stibp vmmcall fsgsbase bmi1 avx2 smep bmi2 erms invpcid avx512f avx512dq rdseed adx smap avx512ifma clflushopt clwb avx512cd sha_ni avx512bw avx512vl xsaveopt xsavec xgetbv1 xsaves avx512_bf16 clzero xsaveerptr arat npt nrip_save tsc_scale vmcb_clean flushbyasid decodeassists pausefilter pfthreshold v_vmsave_vmload avx512vbmi umip avx512_vbmi2 gfni vaes vpclmulqdq avx512_vnni avx512_bitalg avx512_vpopcntdq rdpid fsrm
Virtualization:                       AMD-V
Hypervisor vendor:                    Microsoft
Virtualization type:                  full
L1d cache:                            512 KiB (16 instances)
L1i cache:                            512 KiB (16 instances)
L2 cache:                             16 MiB (16 instances)
L3 cache:                             32 MiB (1 instance)
NUMA node(s):                         1
NUMA node0 CPU(s):                    0-31
Vulnerability Gather data sampling:   Not affected
Vulnerability Itlb multihit:          Not affected
Vulnerability L1tf:                   Not affected
Vulnerability Mds:                    Not affected
Vulnerability Meltdown:               Not affected
Vulnerability Mmio stale data:        Not affected
Vulnerability Reg file data sampling: Not affected
Vulnerability Retbleed:               Not affected
Vulnerability Spec rstack overflow:   Vulnerable: Safe RET, no microcode
Vulnerability Spec store bypass:      Mitigation; Speculative Store Bypass disabled via prctl
Vulnerability Spectre v1:             Mitigation; usercopy/swapgs barriers and __user pointer sanitization
Vulnerability Spectre v2:             Mitigation; Retpolines; IBPB conditional; IBRS_FW; STIBP always-on; RSB filling; PBRSB-eIBRS Not affected; BHI Not affected
Vulnerability Srbds:                  Not affected
Vulnerability Tsx async abort:        Not affected

               total        used        free      shared  buff/cache   available
Mem:           7.4Gi       682Mi       6.1Gi       3.7Mi       746Mi       6.7Gi
Swap:          2.0Gi          0B       2.0Gi

```


## Baseline benchmark

```csv
method,runs,events,mean_duration_ms,mean_events_per_sec,min_events_per_sec,max_events_per_sec,stddev_events_per_sec
blake3_batch,10,1000000,15.5620,64259442.31,63985057.19,64533969.55,147757.61
hmac_sha256_batch,10,1000000,7.2574,137794304.29,135892903.35,138602405.42,772405.94
ksentry_triangular,10,1000000,5.8163,171933263.53,170632274.48,172902212.04,704871.11
merkle_chunks_1024,10,1000000,15.4783,64606801.84,64466722.57,64766759.68,103041.90
rolling_hash_affine,10,1000000,4.3144,231785377.65,230538355.47,232453913.69,536867.81
```

## eBPF pipeline rate

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

## Collector resource usage

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

## File-read workload overhead

```csv
mode,runs,mean_duration_ms,stddev_duration_ms
no_collector,5,6994.4507,468.2826
with_ebpf_collector,5,6885.9846,479.5773
overhead_percent,,-1.5507,
```
WARNING: no real workload raw report found
