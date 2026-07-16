## Wharfside diagnosis report
Wharfside 0.1.1 · container runtime 1.0.0 (commit ee848e3) · macOS 26.5.2
Container: diag-crush · image: docker.io/library/alpine:latest · status: stopped
Generated: 2026-07-09T05:54:57Z

### Digest
```
CONTAINER: diag-crush
IMAGE: docker.io/library/alpine:latest
EXIT_CODE: 1 (from boot log)
WINDOW: logs before container exit
RESTARTS: 0
SOURCE: boot log only (no application output)
FACTS:
EVIDENCE: container exited without writing any application output
COUNTS: INFO=17 UNKNOWN=45 WARN=4
LAST_LINES:
2026-07-16T07:49:10.876Z info vminitd: id: diag-crush, pid: 109 started managed process
2026-07-16T07:49:10.877Z info vminitd: id: diag-crush, status: 1 managed process exit
2026-07-16T07:49:10.877Z info vminitd: id: diag-crush closing relay for StandardIO stdout
2026-07-16T07:49:10.877Z info vminitd: id: diag-crush closing relay for StandardIO stderr
[    0.502572] EXT4-fs (vdb): unmounting filesystem aa598811-9809-4d4d-9c06-5de0b5962e0c.
```

### Diagnosis
Diagnosed by: deterministic precheck (precheck.no-evidence; model not invoked)
Summary: The container exited (status 1) without writing any application output — there is nothing in the logs to analyze. If this exit is unexpected, check whether the command writes errors to stdout/stderr.
Category: unknown · Confidence: low
Suggested actions:
1. Run `container logs diag-crush` to confirm no output was produced
2. If unexpected, run the container's command manually to see its error output
Degraded: false · Retries: 0 · Violations: none
Rulebook: 0.1.0 (bundled) · Rules fired: precheck.no-evidence, noise.vminitd-memory-threshold · Skipped unknown rule kinds: none
