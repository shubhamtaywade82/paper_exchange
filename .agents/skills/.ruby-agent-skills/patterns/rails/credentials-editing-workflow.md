---
name: credentials-editing-workflow
description: Credentials Editing Workflow Contract
family: rails
---
# Credentials Editing Workflow Contract

## Problem
Ad hoc editing of encrypted credentials bypasses auditability and can corrupt environment/key selection.

## Use when
Adding, changing, or rotating credential entries.

## Do not use when
Reading already-defined credentials without modification.

## Repository inspection
Inspect developer commands, editor workflow, environment selection, and CI expectations.

## Implementation procedure
Use bin/rails credentials:edit/show with the repository's environment convention; review diffs and never paste decrypted files into source control.

## Example

```bash
# Edit production credentials with the production key, through Rails, so the
# file stays encrypted and the right environment is selected explicitly.
EDITOR="code --wait" bin/rails credentials:edit --environment production

# Review only which keys changed (values stay encrypted in the diff).
bin/rails credentials:diff --enroll   # one-time: readable git diffs of key names
git diff config/credentials/production.yml.enc
```

## Failure modes
Wrong environment edited, plaintext temporary files committed, or malformed encrypted file.

## Testing
Test edit/show behavior in a safe development/test context and verify repository status.

## Review checklist
[ ] command contract [ ] environment explicit [ ] no plaintext artifact [ ] diff reviewed

## Related skills
rails-encryption-credentials-engineering, rails-test-engineering