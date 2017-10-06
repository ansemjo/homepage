---
title: Signed Npm Version Bumps
date: 2017-01-14
draft: false
toc: true
categories:
  - notes
tags:
  - npm
  - gpg
---

## package.json

For a while now I've been using Visual Studio Code for a few JavaScript / TypeScript projects. Most of these projects come with a `package.json` file, which [documents] various aspects of the project. A tiny example of such a file:

[documents]: https://docs.npmjs.com/files/package.json "npmjs docs: package.json"

```
{
  "name": "foo",
  "version": "1.2.3",
  "description": "A packaged foo fooer for fooing foos",
  "main": "foo.js"
}
```

## npm version

There's that interesting property `version`. In conjunction with the `npm version` command it allows for very easy version bumping with automatic tagging. There are three useful keywords for that command to bump [semver]-compliant versions: `major`, `minor` and `patch`. You can also set a specific version directly but refer to the documentation on npm for details. Observe:

[semver]: http://semver.org/ "Semantic Versioning"

```
/tmp/tmp.tHu9SBWQcl $ git init
Initialized empty Git repository in /tmp/tmp.tHu9SBWQcl/.git/
/tmp/tmp.tHu9SBWQcl $ echo '{ "version": "0.0.0" }' > package.json
/tmp/tmp.tHu9SBWQcl $ npm version patch
v0.0.1
/tmp/tmp.tHu9SBWQcl $ npm version patch
v0.0.2
/tmp/tmp.tHu9SBWQcl $ npm version minor
v0.1.0
/tmp/tmp.tHu9SBWQcl $ npm version patch
v0.1.1
/tmp/tmp.tHu9SBWQcl $ npm version v0.4.0
v0.4.0
/tmp/tmp.tHu9SBWQcl $ npm version major
v1.0.0
/tmp/tmp.tHu9SBWQcl $ git log
8138e90 2017-01-14 (15 seconds ago) 1.0.0
c8f8930 2017-01-14 (21 seconds ago) 0.4.0
ba7fc59 2017-01-14 (36 seconds ago) 0.1.1
3c7d08b 2017-01-14 (38 seconds ago) 0.1.0
00a15b7 2017-01-14 (42 seconds ago) 0.0.2
ff52b31 2017-01-14 (44 seconds ago) 0.0.1
```

## signed tags

Git also supports [signed tags and commits]. To make use of that, first set your preferred GPG Key ID with `git config`:

```
/tmp/tmp.tHu9SBWQcl $ gpg -K demo
sec   rsa2048 2017-01-14 [SC] [expires: 2019-01-14]
      EDB34D547A63C77223A2832C7FDA8637DAC8A82E
uid           [ultimate] Demouser <demo@nope.com>
ssb   rsa2048 2017-01-14 [E] [expires: 2019-01-14]

/tmp/tmp.tHu9SBWQcl $ git config --global user.signingkey EDB34D547A63C77223A2832C7FDA8637DAC8A82E
```

[signed tags and commits]: https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work "Signing Your Work"

Following the above guide on git-scm.com you could now sign your commits with `git commit -S [...]` or your tags with `git tag -s [...]`. Wouldn't it be beautiful to combine npm's version bumping with signing your tags?

Behold! There is npm's `sign-git-tag` option. You could also set this option globally with `npm config set sign-git-tag true`. Or leave it at false and set the flag with every npm command: `npm version [...] --sign-git-tag`.

After reading [this issue] on GitHub, I found out that npm's option parser also allows for abbreviated options, if there is no other option conflicting. This appears to be the case with `--sign`!

[this issue]: https://github.com/npm/npm/issues/7186 "Ability to run npm version without automatically git-committing and tagging"

## signed version bumps

In conclusion, we can now bump our project's version and sign the new tag automatically with `npm version [...] --sign`, which I think is short enough to not require a global setting.

```
/tmp/tmp.tHu9SBWQcl $ npm version minor --sign
v1.1.0
[pinentry dialogue pops up]
/tmp/tmp.tHu9SBWQcl $ git tag -v v1.1.0
object cde27091c4e76438086a91fe0659b6816665d0ae
type commit
tag v1.1.0
tagger Demouser <demo@nope.com> 1484407322 +0100

1.1.0
gpg: Signature made Sat 14 Jan 2017 16:22:02 CET
gpg:                using RSA key EDB34D547A63C77223A2832C7FDA8637DAC8A82E
gpg: Good signature from "Demouser <demo@nope.com>" [ultimate]
```