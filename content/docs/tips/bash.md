# Bash

## Check if a variable is defined

The simplest approach of using `if [[ -n $var ]]; then ..` cannot detect if the
variable has been defined but is assigned an empty value.

If this distinction is important, e.g. when writing user-facing commandline
scripts you can use the `${var+isdefined}` expansion. For example:

**Check if a variable is defined:**

```bash
if [[ -n ${var+defined} ]]; then
  do something with $var
fi
```

**Error if argument was not given:**

```bash
if [[ -z ${1+undefined} ]]; then
  echo "error, argument required" >&2
fi
```
