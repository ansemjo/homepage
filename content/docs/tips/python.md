---
title: Python
weight: 10
---

# Python

## Embedding Version Information in Packages

{{< hint info >}}
For a real example see [tinyssh-keyconvert@0.3.1...0.3.2](https://github.com/ansemjo/tinyssh-keyconvert/compare/0.3.1...0.3.2).
{{< /hint >}}

Version information should be single-sourced if you ask me. I've described my thoughts
in a [blog post]({{< ref "/posts/2018/git-version-string/index.md" >}}), which culminated
in my [ansemjo/version.sh](https://github.com/ansemjo/version.sh) script.

To solve this problem for Python packages:

- Use `version.sh` script
  - Modify the release seperator to `-dev`
  - Use only `version` output, not `describe`, to conform to PEP440
- Read version from script with a `subprocess` command during packaging
- Write that version into a simple file that exports `__version__` in your package
- In your script try to import said `__version__` in a `try-except`-clause and fallback
- Now you can use the same `version` in the script .. yay!
