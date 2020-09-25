# Python

## Embedding version information in packages with `setuptools`

TODO, see https://github.com/ansemjo/tinyssh-keyconvert/compare/0.3.1...0.3.2

Basically:

- use version.sh script
  - modify release seperator to '-dev'
  - use only 'version' output, not 'describe' to conform to pep 440
- read version when packaging with a subprocess cmd, use directly in hash
- write that version into a simple file that exports `__version__` in your package
- in your script try to import said `__version__` in a try-except-clause and fallback
- now you can use the same version in the script, yay
