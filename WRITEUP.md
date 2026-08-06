# CGE-P Capstone Write-Up

The HIPAA Security Rule is the primary framework for this capstone because the Acme Health Patient Intake API processes patient information that may constitute protected health information. The implementation uses infrastructure as code, policy as code, automated evidence generation, cryptographic signing, immutable storage, and OSCAL to make the working application audit-defensible.

## Architecture and design decisions

See [`docs/design-decisions.md`](docs/design-decisions.md).

## Gap remediation

Implementation details will be recorded here after each technical control is
deployed and verified.

## Control coverage

See [`docs/control-mapping.md`](docs/control-mapping.md).

## Policy-as-code design

This section will document the five Rego policies, their tests, metadata, and
fail-closed pipeline behavior.

## Evidence and chain of custody

This section will document evidence collection, SHA-256 hashing, Cosign
signing, S3 VersionIds, and Object Lock retention.

## Trade-offs

The capstone uses one AWS sandbox account and Governance-mode Object Lock.
A production implementation would preferably separate workload and evidence
accounts and use stronger separation of administrative duties.

## What I would do with another sprint

This section will be completed after the required implementation is stable.

## Work not completed

This section will truthfully identify any incomplete requirement before the
graded commit is selected.
