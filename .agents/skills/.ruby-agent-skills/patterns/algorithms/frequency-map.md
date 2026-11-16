---
name: frequency-map
description: Use when counting occurrences or testing membership efficiently with a hash-backed frequency/index structure.
family: algorithms
---

# Frequency Map

## Problem

Repeated membership/counting scans make a collection algorithm unnecessarily quadratic.

## Use when

- membership/counting is the dominant operation
- additional O(n) space is allowed
- the input values are suitable hash keys

## Do not use when

- the task explicitly requires O(1) auxiliary space
- memory is constrained enough that the index is unacceptable
- ordering/identity semantics make hashing inappropriate

## Repository inspection

Inspect the input contract, ordering guarantees, mutation constraints, complexity requirements, and existing algorithm conventions before selecting this pattern.

## Structure

~~~ruby
counts = values.each_with_object(Hash.new(0)) do |value, result|
  result[value] += 1
end
~~~

## Implementation procedure

1. Identify the repeated lookup/counting operation.
2. Define the hash key semantics.
3. Build the index in one pass when possible.
4. Consume it in the second phase or simultaneously if safe.
5. State time and auxiliary-space complexity.
6. Consider input mutation/ownership.

## Failure modes

- using a hash when the problem requires O(1) auxiliary space
- mutable/unhashable key assumptions
- silently changing ordering semantics
- building multiple redundant indexes

## Testing

Test empty input, duplicates, missing keys, high-frequency values, and representative large inputs.

## Review checklist

- [ ] hash key semantics are correct
- [ ] extra space is allowed
- [ ] complexity stated accurately
- [ ] duplicates handled
- [ ] ordering semantics preserved

## Related skills

- ruby-collections
- ruby-data-types
- ruby-control-flow
- ruby-tdd-refactoring
