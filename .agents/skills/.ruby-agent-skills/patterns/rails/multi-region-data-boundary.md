---
name: multi-region-data-boundary
description: Partition a Rails application across geographic regions with explicit region routing, authoritative write ownership, data residency, replication lag budgets, and fenced failover only when a concrete requirement exists.
family: rails
---

# Multi-Region Data Boundary

## Problem

Latency, compliance, or regional-availability requirements push an application toward multiple geographic regions, but naive region-spanning state introduces split-brain writes, residency violations, unbounded replication assumptions, and failover procedures nobody has rehearsed.

## Use when

A concrete requirement exists that a single region cannot satisfy: data must physically reside in a jurisdiction; latency SLAs are unreachable from one region; or availability must survive a full regional outage.

## Do not use when

A single region plus CDN edge caching satisfies the latency goal; the motivation is architectural ambition rather than a stated requirement; the dataset is small enough that synchronous replication needs no design; or no compliance constraint requires geographic separation.

## Repository inspection

Inspect region routing (DNS, global load balancer, request steering), the authoritative write region, database replication topology and placement (primary, replicas, observed lag), residency-restricted tables/columns and every access path that can move them, failover automation and stated RPO/RTO, region-local dependencies (jobs, caches, blob storage buckets, mailers), and clock/latency assumptions inside cross-region request paths.

## Implementation procedure

1. State the requirement (residency, latency, or regional availability) that single-region cannot satisfy.
2. Choose an ownership model: single write region with read replicas, region-partitioned tenants or data, or independent per-region stacks with reconciliation.
3. Define the authoritative write region plus replication direction and an explicit lag budget for every data store.
4. Mark residency-restricted data and enforce placement at the storage layer, not by application convention.
5. Define region routing: which requests go where, how a user is pinned, and how pinning behaves during failover.
6. Define failover: promotion procedure, fencing against the old primary (lease or quorum on the write role), who executes it, and stated RPO/RTO.
7. Define conflict handling for anything written during the failover window, including explicit reconciliation or discard rules.
8. Map region-local dependencies (jobs, cache, blob storage, mailers) and their failover targets.
9. Rehearse promotion and failback before claiming regional availability.
10. Document the blast radius: what is lost, queued, or reconciled when a region is unreachable.

## Example

```markdown
## Data placement by region

| Data                  | Home region        | Writes                  | Reads elsewhere            | Conflict rule                 |
|-----------------------|--------------------|-------------------------|----------------------------|-------------------------------|
| Accounts, users       | per-tenant (in/eu) | home region only        | proxied to home region     | none (single writer)          |
| Orders, payments      | per-tenant         | home region only        | never replicated out (DPDP)| none                          |
| Product catalog       | global primary (in)| primary only            | async read replicas        | replicas may lag ≤ 60 s       |
| Sessions              | region of login    | local                   | re-authenticate on move    | —                             |

Routing: `tenants.home_region` decides the database; a request landing in the wrong
region is forwarded, never served from a stale replica for writes.
```

## Failure modes

- multi-region topology adopted without a requirement
- writes accepted in two regions with no conflict resolution contract
- residency enforced only by application convention
- replica lag treated as zero
- failover promotion without fencing against the old primary
- synchronous cross-region calls inside a user request
- region-local jobs or caches silently pointing at the wrong region after failover
- stale CDN or edge responses served from a failed region's assets
- promotion or failback never rehearsed
- RPO/RTO stated but never measured

## Testing

Test replication lag behavior under load, residency enforcement (writes that would place restricted data cross-region must fail), failover promotion with a fenced old primary, re-routing of pinned users after failover, conflict resolution for dual writes in the failover window, and degraded read paths when the write region is unreachable.

## Review checklist

- [ ] single-region alternative explicitly rejected
- [ ] write ownership model stated
- [ ] replication lag budget explicit
- [ ] residency enforced at the storage layer
- [ ] failover procedure fenced and rehearsed
- [ ] RPO/RTO stated and measurable
- [ ] conflict handling defined
- [ ] region-local dependencies mapped
- [ ] cross-region calls stay out of user request paths

## Related skills

- rails-distributed-systems
- rails-database-engineering
- rails-reliability-engineering
- rails-production-runtime
- rails-active-storage

## Related patterns

- distributed-service-boundary
- eventual-consistency
- distributed-lock
