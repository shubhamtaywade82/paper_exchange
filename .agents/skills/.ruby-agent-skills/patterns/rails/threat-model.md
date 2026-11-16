---
name: threat-model
description: Map assets, actors, trust boundaries, attacker capabilities, abuse cases, controls, and residual risk for a Rails feature or architecture.
family: rails
---

# Threat Model

## Problem

Security reviews jump directly to implementation findings without identifying what must be protected, who can attack it, and where trust changes.

## Use when

A feature introduces new sensitive data, privileges, providers, services, or execution boundaries.

## Do not use when

The change is a narrow local fix whose threat boundary is already explicit and unchanged.

## Repository inspection

Inspect assets, actors, entry points, trust boundaries, authorization, dangerous sinks, external providers, jobs, queues, and existing security controls.

## Implementation procedure

1. List high-value assets.
2. Identify actors and capabilities.
3. Draw trust boundaries and data flows.
4. Mark attacker-controlled inputs.
5. Identify dangerous sinks and privilege transitions.
6. Enumerate concrete abuse cases.
7. Rank by impact and exploitability.
8. Map preventive/detective/recovery controls.
9. Add executable abuse-case tests.
10. Record residual risk and ownership.

## Example

```markdown
## Threat model: customer document uploads

**Assets:** uploaded KYC documents (PII), signed download URLs, storage credentials.
**Actors:** customers (own documents), support staff (read, audited), anonymous internet.

| Trust boundary                     | Threat                                   | Control                                        |
|------------------------------------|------------------------------------------|------------------------------------------------|
| Browser → app (upload)             | malicious file, oversized upload         | size cap 10 MB, Marcel type check, AV scan job |
| Browser → app (download)           | IDOR on blob id                          | download through authorized controller, not public blob URL |
| App → S3                           | leaked credentials, public bucket        | IAM role per env, bucket policy denies public  |
| Support tool → documents           | insider browsing                          | reason required, audit event per view          |
| Signed URL → third parties         | URL forwarded                             | 5-minute expiry, `disposition: attachment`     |

Residual risk: AV scan is async; documents are unviewable until scanned.
```

## Failure modes

- generic threat list without repository data flow
- treating all findings as equal
- missing alternate execution paths
- controls listed without verification
- residual risk with no owner

## Testing

Each high-impact abuse case should have a focused executable regression where practical.

## Review checklist

- [ ] assets identified
- [ ] actors/capabilities identified
- [ ] trust boundaries identified
- [ ] abuse cases concrete
- [ ] controls mapped
- [ ] verification present
- [ ] residual risk owned

## Related skills

- rails-security-engineering
- rails-security
- rails-test-engineering
