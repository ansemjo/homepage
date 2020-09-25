---
title: restic
weight: 10
---

# restic

These tips are assuming that you have your `RESTIC_REPOSITORY` and necessary API keys, e.g.
`B2_ACCOUNT_{ID|KEY}`, set in your environment. This enables you to simply use `restic [command]`
instead of specifying the repository with `-r <repo>` and entering the password interactively.

## Restore a Single File

List your snapshots:

```sh
restic snapshots
```

Fetch a list of files within a snapshot or search for one:

```sh
restic ls -l {latest|snapshot-id}
restic find
```

Restore a single file matching a pattern:

```sh
restic restore \
  --target /restore/path \
  --include filename_or_pattern \
  {latest|snapshot-id}
```

## Mount and Browse a Snapshot

Or mount a snapshot and browse inside interactively:

```sh
restic mount /mount/path
ls -la /mount/path
```
