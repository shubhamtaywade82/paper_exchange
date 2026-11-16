---
name: two-pointers
description: Use for sorted-array or two-ended search problems where two moving indices can reduce nested search to linear traversal after required preprocessing.
family: algorithms
---

# Two Pointers

## Problem

A search over pairs or boundaries appears quadratic because every element is compared with every other element.

## Use when

- input is sorted or can be sorted without violating the contract
- pair relationships can be reasoned about from left/right movement
- the task explicitly permits sorting

## Do not use when

- ordering is semantically meaningful and cannot change
- the required auxiliary-space/complexity contract makes sorting inappropriate
- pointer movement cannot be justified by a monotonic invariant

## Repository inspection

Inspect the input contract, ordering guarantees, mutation constraints, complexity requirements, and existing algorithm conventions before selecting this pattern.

## Structure

~~~ruby
left = 0
right = values.length - 1

while left < right
  sum = values[left] + values[right]

  if sum == target
    return [left, right]
  elsif sum < target
    left += 1
  else
    right -= 1
  end
end

nil
~~~

## Implementation procedure

1. Establish the ordering invariant.
2. Define what each pointer represents.
3. Prove why moving a pointer cannot discard a valid solution under the problem constraints.
4. Move exactly one/both pointers according to the invariant.
5. Handle duplicates and boundaries.
6. State preprocessing complexity separately from scan complexity.

## Failure modes

- using two pointers on unsorted data without preprocessing
- moving a pointer without an invariant
- returning wrong duplicate combinations
- forgetting empty/singleton inputs
- claiming O(n) when sorting is part of the algorithm

## Testing

Test empty, singleton, duplicate, target-at-boundary, no-match, and multiple-match cases. Report total complexity including sorting when sorting is used.

## Review checklist

- [ ] invariant is explicit
- [ ] pointer movement is justified
- [ ] ordering requirement satisfied
- [ ] total complexity is correct
- [ ] duplicates/boundaries tested

## Related skills

- ruby-control-flow
- ruby-collections
- ruby-tdd-refactoring
