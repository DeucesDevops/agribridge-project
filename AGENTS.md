# AgriBridge project instructions

## Branch workflow

- Make all project changes on the existing `dev` branch.
- Do not create additional development branches or commit changes directly to `main`.
- Publish changes to `dev`, then open a pull request from `dev` to `main`.
- Check the pull request's validation results before merging through GitHub.
- After merging, synchronize `dev` to the resulting merge commit with a fast-forward;
  do not rewrite branch history or open a reverse pull request.

## Attribution and operations

- Attribute work performed for the owner to the existing `DeucesDevops` Git identity.
- Preserve the original authorship of third-party source and automated release commits.
- Do not provision AWS resources as part of source cleanup or offline validation.
