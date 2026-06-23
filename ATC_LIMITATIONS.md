# TimeFence ATC Limitations

## 1. WSL prototype evaluation

Most current experiments were run in WSL.

This is useful for rapid development and prototype validation, but it is not enough for final ATC claims.

Before submission, the main experiments should be rerun on:

- native Ubuntu Linux
- a cloud VM
- or a university Linux server

Main experiments to rerun:

- eBPF pipeline throughput
- TimeFence vs baseline workload overhead
- collector CPU/RSS
- real workload experiment
- stress sweep
- build workload
- ring-buffer output-failure accounting

Paper wording:

The current artifact was developed and evaluated primarily in WSL. Native Linux/cloud VM reruns are required before making production-scale systems claims.

---

## 2. ringbuf_output_failures accounting is incomplete in WSL

TimeFence now separates:

- kept_events
- filtered_events
- ringbuf_output_failures

This is better than the older skipped_events wording.

However, in WSL the ring-buffer output-failure map may not be exposed reliably to userspace. Current WSL reports may show:

ringbuf_output_failures=not_available_map_not_found

This means the prototype attempted to add kernel-side ring-buffer output-failure accounting, but the map lookup did not work reliably in the WSL environment.

Before ATC submission, this must be validated on native Linux.

Desired final result:

ringbuf_output_failures=0

or a measured nonzero value under pressure.

---

## 3. eBPF ingestion is not formally verified

The K-Sentry accumulator core is verified.

The Linux/eBPF ingestion path is not verified.

Trusted components include:

- Linux kernel tracepoints
- eBPF program loading
- Aya runtime
- Rust userspace collector
- event canonicalization path
- checkpoint storage

The paper should be clear:

The proof applies to the accumulator and specification-refinement core, not to the entire Linux kernel telemetry stack.

---

## 4. Not a cryptographic MAC

K-Sentry is a finite-field fingerprinting accumulator.

It provides a polynomial collision bound under random q.

It is not a replacement for:

- HMAC
- digital signatures
- authenticated encryption
- tamper-proof storage

Correct wording:

TimeFence provides compact order-sensitive sequence evidence. It should be combined with authenticated checkpoint storage when adversaries may modify stored checkpoints.

---

## 5. IPv6 is not decoded yet

IPv4 connect decoding works.

Examples:

- Connect:curl:172.66.147.243:80
- Connect:curl:34.223.124.45:80

Current limitation:

- IPv6/non-IPv4 events are reported as socket_connect_non_ipv4.

Before a stronger network-telemetry claim, IPv6 decoding should be implemented.

---

## 6. Userspace filtering is still simple

Current prototype policy keeps:

- selected Exec commands
- selected OpenFile paths
- all Connect events

Events not matching policy are counted as filtered_events.

filtered_events means the event reached userspace but was ignored by policy.

It does not mean the event was lost.

Future work should move more filtering into eBPF maps or kernel-side predicates to reduce userspace event pressure.

---

## 7. Workloads are still prototype-level

Current workloads include:

- file-read overhead workload
- Python HTTP + curl workload
- stress workload
- comparison file/network workload
- strace ingestion cases

These are useful prototype experiments.

ATC would be stronger with:

- cargo build / cargo test workload
- package install workload
- git clone + grep/find workload
- Flask/nginx workload
- longer-running service workload
- native Linux/cloud reruns

---

## 8. Tool comparison is not fully measured yet

The paper currently has a conceptual comparison with:

- auditd
- Falco
- Tetragon
- OpenTelemetry

But full measured comparison is not finished yet.

Before ATC submission, ideally run the same workload with:

- no monitor
- TimeFence
- auditd
- Falco or Tetragon if feasible

Metrics:

- runtime overhead
- CPU usage
- memory usage
- event visibility
- deployment complexity
- whether sequence-integrity evidence is provided

---

## 9. Pipeline throughput is WSL-specific

Current eBPF pipeline throughput is measured in WSL.

Example WSL results:

- N=500: about 493.6 observed events/sec
- N=1000: about 398.2 observed events/sec
- N=2000: about 277.2 observed events/sec

These include:

- syscall generation
- eBPF ring-buffer delivery
- userspace filtering
- event canonicalization
- field-element mapping
- K-Sentry update

These should not be presented as maximum system capacity.

Correct wording:

These are WSL prototype pipeline measurements. Native Linux/cloud reruns are needed for final systems-performance claims.

---

## 10. Threat model excludes kernel compromise

TimeFence does not protect against an attacker who controls:

- the kernel
- the loaded eBPF program
- the userspace collector binary
- trusted checkpoint storage
- verifier execution

TimeFence detects tampering with the observed telemetry sequence after collection, assuming the collection and verification path remains trusted.

---

## 11. Current conclusion

TimeFence is a complete research prototype.

It is not yet a production-grade telemetry platform.

The correct ATC framing is:

TimeFence demonstrates a verified streaming evidence layer for Linux telemetry and evaluates a working eBPF prototype. Final ATC submission requires native Linux/cloud validation, stronger workloads, complete ring-buffer accounting, and measured comparison with existing telemetry tools.
