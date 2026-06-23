# TimeFence Related Work

## 1. Rolling hashes and polynomial fingerprints

Rolling hashes summarize a sequence using position-dependent polynomial weights.

A standard form is:

R(w; q, p) = sum_i x_i q^i mod p

This is fast and supports streaming updates.

However, affine exponents are shift-rebaseable:

sum_i x_i q^(i+s) = q^s sum_i x_i q^i

This means a segment digest can be shifted by multiplying by q^s.

TimeFence differs by using non-affine positional weights.

The implemented triangular variant uses:

T_i = i(i+1)/2

A_T(w; q, p) = sum_i x_i q^{T_i} mod p

This breaks the simple scalar rebase property.

How to position:

Rolling hashes are the speed baseline. TimeFence keeps a compact streaming structure but avoids affine digest-only rebasing.

---

## 2. Cryptographic hashes and HMAC

Cryptographic hashes and HMAC provide strong integrity and authentication properties.

Examples:

- SHA-256
- HMAC-SHA256
- BLAKE3

TimeFence does not replace these tools.

Instead, TimeFence targets a different design point:

- streaming sequence evidence
- order-sensitive event checkpoints
- compact telemetry digest
- verified accumulator core

In the current benchmark, K-Sentry triangular was faster than HMAC-SHA256 and BLAKE3 batch baselines on scalar-event input, but this does not mean it is cryptographically stronger.

Correct framing:

HMAC provides cryptographic authentication. TimeFence provides verified finite-field sequence evidence. For adversarial storage, TimeFence checkpoints should be authenticated or stored in a trusted log.

---

## 3. Merkle trees

Merkle trees provide integrity over sets or sequences of data blocks.

They support:

- membership proofs
- tamper-evident structure
- hierarchical verification

However, Merkle trees require tree construction and maintenance.

TimeFence differs by producing a single streaming digest with constant-state updates.

Tradeoff:

- Merkle trees provide structured proofs and strong cryptographic hashing.
- TimeFence provides lightweight streaming sequence evidence with a verified accumulator.

Correct framing:

Merkle trees are a strong integrity baseline. TimeFence explores a lower-state streaming checkpoint design for telemetry sequences.

---

## 4. Linux auditd

auditd is Linux’s audit logging system.

It records security-relevant events from the kernel.

Strengths:

- mature Linux audit infrastructure
- compliance and forensic logging
- kernel-level event source
- widely deployed

Limitations relative to TimeFence:

- no verified accumulator core
- no compact order-sensitive sequence digest
- no K-Sentry-style checkpoint
- log integrity must be handled externally

How TimeFence relates:

TimeFence could run alongside auditd to produce sequence-integrity checkpoints over selected audit-style event streams.

---

## 5. Falco

Falco is a runtime security detection engine.

It observes system activity and applies rules for suspicious behavior.

Strengths:

- practical runtime detection
- rule language
- container and Kubernetes ecosystem
- syscall/eBPF visibility

Limitations relative to TimeFence:

- focuses on semantic detection rules
- does not provide verified sequence evidence
- does not produce compact order-sensitive checkpoints over the event stream
- alerts do not prove that the full telemetry stream was not reordered, spliced, or same-length modified

How TimeFence relates:

Falco detects suspicious behavior. TimeFence attests sequence integrity. These are complementary properties.

---

## 6. Tetragon

Tetragon is an eBPF-based security observability and enforcement system.

Strengths:

- eBPF-based process, file, and network observability
- Kubernetes integration
- policy and enforcement capabilities
- practical cloud-native deployment

Limitations relative to TimeFence:

- not designed as a verified sequence-evidence layer
- no K-Sentry-style finite-field accumulator
- no verified order-sensitive checkpoint core
- stronger as an observability/enforcement platform than as a compact formal evidence system

How TimeFence relates:

Tetragon can collect rich telemetry. TimeFence can provide compact sequence evidence over telemetry streams.

---

## 7. OpenTelemetry

OpenTelemetry standardizes logs, metrics, and traces across systems.

Strengths:

- broad observability ecosystem
- distributed tracing
- vendor-neutral telemetry format
- integration with many backends

Limitations relative to TimeFence:

- not a sequence-integrity digest system
- no verified accumulator
- does not detect reorder/splice/duplicate attacks through compact finite-field checkpoints
- focuses on telemetry transport and observability, not formal evidence

How TimeFence relates:

OpenTelemetry can carry telemetry. TimeFence can add sequence-integrity evidence to telemetry pipelines.

---

## 8. Runtime monitoring and security observability

Many runtime systems monitor processes, files, and network events.

These systems generally focus on:

- detection
- alerting
- policy enforcement
- observability
- forensics

TimeFence focuses on a narrower property:

Was the telemetry sequence preserved?

This includes:

- same order
- same length
- same content
- no splice
- no duplicate
- no truncation

TimeFence is not a detection-rule engine. It is an evidence layer.

---

## 9. Streaming verification

Streaming verification studies how a verifier can check properties of large streams using limited space.

TimeFence connects this idea to Linux telemetry.

It uses a compact digest and finite-field reasoning to detect changes in event streams.

Unlike abstract streaming-only systems, TimeFence includes:

- Rust implementation
- strace ingestion
- eBPF live collection
- overhead measurements
- real workload reports

How to frame:

TimeFence brings a streaming-verification style accumulator into a concrete Linux telemetry setting.

---

## 10. Verified systems

Verified systems use formal methods to prove properties of software components.

TimeFence verifies the accumulator core, not the whole OS pipeline.

Verified part:

- K-Sentry accumulator/refinement core
- updater/spec consistency

Trusted/unverified part:

- Linux kernel
- eBPF tracepoints
- Aya runtime
- userspace collector
- filesystem/checkpoint storage

Correct framing:

TimeFence is a partially verified system: the mathematical evidence core is verified, while the telemetry ingestion layer is implemented and empirically evaluated.

---

## 11. What is unique about TimeFence

TimeFence combines:

1. non-affine order-sensitive finite-field sequence evidence
2. verified accumulator core
3. Rust implementation
4. real strace ingestion
5. live eBPF exec/open/connect ingestion
6. IPv4 connect destination evidence
7. overhead and pipeline evaluation

The novelty is not any single component alone.

The novelty is the connection:

verified streaming evidence
+
real Linux telemetry ingestion

---

## 12. Related work positioning sentence

Existing telemetry systems collect, transport, or analyze security events. Existing integrity structures authenticate logs or data blocks. TimeFence occupies a different point: it provides a verified, order-sensitive streaming evidence layer that can compactly attest whether a Linux telemetry sequence was reordered, truncated, duplicated, spliced, or same-length modified.

---

## 13. Related work table

| Area | Examples | What they provide | What TimeFence adds |
|---|---|---|---|
| Rolling hashes | polynomial rolling hash | fast streaming summaries | non-affine anti-rebase sequence evidence |
| Cryptographic hashes | SHA-256, BLAKE3 | strong batch integrity | streaming verified telemetry checkpoints |
| MACs | HMAC-SHA256 | cryptographic authentication | order-sensitive finite-field sequence evidence |
| Merkle trees | hash trees | structured integrity proofs | constant-state streaming checkpoint |
| Linux auditing | auditd | kernel audit logs | compact verified sequence digest |
| Runtime detection | Falco | rule-based alerts | sequence-integrity evidence |
| eBPF observability | Tetragon | rich kernel telemetry | verified accumulator over event stream |
| Observability pipelines | OpenTelemetry | traces/logs/metrics | compact order-sensitive checkpoint |
| Verified systems | Verus-style proofs | proved components | verified accumulator connected to Linux telemetry |
