---
title: bash
weight: 10
---

# bash

## Check if a variable is defined

The simplest approach of using `if [[ -n $var ]]; then ..` cannot detect if the
variable has been defined but is assigned an empty value.

If this distinction is important, e.g. when writing user-facing commandline
scripts you can use the `${var+defined}` expansion. For example:

**Check if a variable is defined:**

```bash
if [[ -n ${var+defined} ]]; then
  # do something with $var
fi
```

When the variable is defined, the variable will expand to `defined` and the
`not empty` test will succeed.

**Error if argument was not given:**

```bash
if [[ -z ${1+undefined} ]]; then
  echo "error, argument required" >&2
fi
```

Whenever the variable is defined, it will expand to `undefined` which will
**fail** the `is empty` test -- only when it is *not defined* will this test
succeed.
