---
name: change-coupling-contract
description: Change Coupling Contract
family: architecture
---
# Change Coupling Contract

## Problem
Architecture can look modular while routine business changes still require synchronized edits across many boundaries.

## Use when
Repeated changes require coordinated edits in unrelated modules/services/teams.

## Do not use when
A one-off change has not demonstrated structural coupling.

## Repository inspection
Inspect recent commits/PRs when available, dependency edges, shared tables, common serializers, and release coupling.

## Implementation procedure
Identify the recurring coupling mechanism and change the ownership boundary rather than merely moving files.

## Example

```bash
# Which directories change together? Frequent pairs across a claimed
# boundary show the boundary is not really independent.
git log --since="6 months ago" --name-only --pretty=format:"--" -- app \
  | awk -F/ '/^--$/{if (n) print dirs; dirs=""; n=0; next} {d=$1"/"$2; if (index(dirs, d)==0) {dirs=dirs" "d; n++}} END{print dirs}' \
  | tr ' ' '\n' | sort | uniq -c | sort -rn | head -20
```

## Failure modes
Cosmetic modularity, excessive interfaces, no reduction in coordinated change.

## Testing
Compare before/after touched-boundary evidence where practical.

## Review checklist
[ ] recurring coupling [ ] causal mechanism [ ] measurable improvement

## Related skills
rails-staff-principal-architecture, agent-workflow