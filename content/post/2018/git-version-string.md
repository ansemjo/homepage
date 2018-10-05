---
title: Commit hash replacement in Git archives
description:
  use $Format:%h$ in a file and mark for substitution in downloaded archives with 'file
  export-subst' in .gitattributes
date: 2018-10-05T19:09:08+02:00

tags:
  - git
  - development
---

Trying to implement some sort of automatic versioning based on your git commits or tags is not as
easy as it should seem. The idea is to use a feature built into the revision control system to
modify your project files and increment version counters automatically or embed commit information
into software builds - in my case: the `--version` output of Go applications built with
[cobra](https://github.com/spf13/cobra).

Ideally, the solution should not require executing some hacked-together scripts or configuring
overly many settings on developer machines, yet still embed version information when a user
donwloads a release to build locally. The simpler, the better.

# git hooks

My first intention was to use [git hooks](https://git-scm.com/docs/githooks). They reside in a
project's `.git/hooks/` directory and there are a number of different hooks for various steps in
your workflow.

There is a `pre-commit` hook, which is executed right before saving the new commit. However, you
cannot use the hash of the commit-to-be in your script, because that hash does not exist yet at this
point. And even if you were to change any file at this point, the commit hash would change and you
would need to change the file again ... you see where this is going.

My biggest gripe with this solution is that custom scripts in the `.git/` directory are not added to
the repository itself. That means that a fresh clone will not contain those custom hooks of yours.

# build-time scripts

Go supports setting package-level variables at compile time with this `-ldflags` syntax:

    go build -ldflags "-X main.commit=$COMMIT_HASH"

This is exactly what [build.go](https://github.com/fd0/build-go) does and surely, this is a powerful
tool. But again, this requires some custom build-time scripts, requires that `git` is installed to
use `rev-parse` and it must be used in a git clone which includes all this commit information. I
agree, this should almost be a given on a developer machine but this is not necessarily the case for
a downloaded `.tar.gz` archive and you can't use a simple `go get ...`.

# gitattributes

Enter [.gitattributes](https://git-scm.com/docs/gitattributes). You can define a number of different
normalization operations with gitattributes. Among them are filters and substitutions.

## filters

Filters defined in you `.gitattributes` file are really powerful. They enable you to save one thing
in the repository and replace it with something dynamically generated upon checkout. For example,
replace a given string with the output of `git describe` upon checkout but substitute the original
string before committing the blob to the tree.

This looked almost perfect as it allowed nearly every imaginable version string replacement. Except:
the filter commands are saved in your git config (`.git/config` or `~/.gitconfig`) and are not
transferred together with the rest of the git tree when pushing or cloning. Which makes sense,
because it would otherwise allow for arbitrary command-execution upon checkout. Imagine a filter
command which quietly uploads you ssh keys to a pastebin? Yeah, you don't want that.

## export-subst

Finally, there's the `export-ignore` and `export-subst` attributes. The former allows you to ignore
certain files during archive creation and the latter allows you to specify
[pretty-format](https://git-scm.com/docs/pretty-formats) strings to be replaced. Archive creation
with `git archive` is what happens when you click the "Download" button on a GitHub repository, for
example.

Consider this quick example:

    $ git init
    $ echo VERSION export-subst > .gitattributes
    $ echo 'commit $Format:%h$' > VERSION
    $ git add .
    $ git commit -m versiontest
    [master (root-commit) 4d61167] versiontest
     2 files changed, 2 insertions(+)
     create mode 100644 .gitattributes
     create mode 100644 VERSION
    $ git archive HEAD | tar x VERSION --to-stdout
    commit 4d61167

You see that we created a `VERSION` file with the content `commit $Format:%h$` and it got replaced
with the proper commit hash in the exported tar archive. Experiment with different format strings
and see what you can create. Unfortunately you cannot produce output identical to `git describe` but
the given seems good enough.

The problem with this approach is somewhat inverse: in your development checkout you will have the
raw `$Format:...$` string in the file. However, I think this is easily manageable with a simple `if`
conditional. If you find the `Format:` substring, use a default (e.g. `(development)`) and otherwise
assume that the variable contains the proper commit hash and `fmt.Sprintf(...)` some proper string.
Just make sure to not try and match the full format string including the enclosing `$`'s as those
will then be replaced too ...

Then when you build your software for a release, use a temporary directory and a locally exported
git archive. Consider the example of [aenker](https://github.com/ansemjo/aenker), which is built
with [mkr](https://github.com/ansemjo/makerelease). In `cli/version.go` I have:

    package cli

    import "strings"

    const Version = "0.4"
    const Commit  = "$Format:%h$"

    func SpecificVersion() string {
    	if strings.Contains(Commit, "Format:") {
    		return Version + " (development)"
    	}
    	return Version + " (commit " + Commit + ")"
    }

And when building a release this command gets executed:

    git archive --prefix=./ HEAD | mkr release

Thus the release is always built from a tar archive, where the proper commit hash has been inserted.
And if you want to install a specific version with Go, simply download and extract an archive and
then call `go install` from within it - no custom build script, Go only. Yes, I still need to update
the `Version` const occasionally. But by omitting the patch level I don't need to do that too often
and the commit hash which is always included is way more specific anyway.

So if you use a simple `go get`:

    $ go get -u github.com/ansemjo/aenker
    $ aenker --version
    aenker version 0.4 (development)

And if you download a specific archive to a temporary directory:

    $ curl -L https://github.com/ansemjo/aenker/archive/0.4.0.tar.gz | tar xz --strip-components=1
    $ go install
    $ aenker --version
    aenker version 0.4 (commit baba7be)

# summary

To sum up ..

- use a `$Format:...$` string in a file which should contain version information
- mark that file for substitution with `path/to/file export-subst` in your project's
  `.gitattributes` file
- build your software from `git archive HEAD` archives
- optionally check for the `Format:` substring and replace with a default like `development`
