# Public cloud Mac verification

The standard macOS workflow builds the unsigned app and runs routing tests. It runs on a push to main or manual dispatch. It has read-only contents permission, no saved checkout credentials, no signing/distribution and no cache/artifact uploads. A private repository must explicitly confirm available allowance before its runner job can start.

GitHub documents standard hosted runners in public repositories as free: https://docs.github.com/en/billing/concepts/product-billing/github-actions

Simulator compilation and tests do not remove Apple signing/provisioning requirements for installation on a physical iPad.
