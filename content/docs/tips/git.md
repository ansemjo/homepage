---
title: git
weight: 10
---

# git

## Prevent commits on a branch

You can use a `pre-commit` hook to check the branch name to which you are commiting your changes. If
you want to prevent direct changes to `master` create the following `.git/hooks/pre-commit`:

```
#!/bin/sh

# prevent commits on master
[ "$(git rev-parse --abbrev-ref --symbolic-full-name HEAD)" == "master" ] \
  && { echo "you shall not commit on master"; exit 1; }
```

Make sure the hook script is executable.

## Merge Repositories

I've had a few situations where I started front- and backend as two seperate projects but soon
wished to track both in a single repository - as subdirectories. Last time I was in this situation,
[a stackoverflow answer](https://stackoverflow.com/a/6442034) proved most helpful. Here's the gist:

Assume you have two repositories `frontend` and `backend`.

### Prepare repositories

First, you should move all files in each repository into a subdirectory to avoid merge conflicts and
properly preserve commit history later. It would make sense to put all files in the `frontend`
repository into a `frontend` subdirectory .. etc.

```
⦁ project/front : master= $ mkdir frontend
⦁ project/front : master= $ mv !(frontend) frontend/
⦁ project/front : master *%= $ git add .
⦁ project/front : master += $ git commit
[master c777b42] prepare frontend for merge
 65 files changed, 0 insertions(+), 0 deletions(-)
 [...]
```

{{< hint danger >}}
Don't forget about hidden files, as those are not moved by `mv !(frontend) frontend/`.
{{< /hint >}}

Do the same analogously for the `backend` or any other repository you want to merge.

Also, create a new repository to hold the merged projects. It helps to create an initial commit --
even if completely empty -- to indicate that unrelated histories were merged into each other.

```
⦁ project $ mkdir project && cd project
⦁ project/project $ git init
⦁ project/project : master # $ git commit --allow-empty
```

### Add and fetch remotes

Add all prepared repositories as remotes and fetch them.

```
⦁ project/project : master $ git remote add -f frontend ../frontend
⦁ project/project : master $ git remote add -f backend ../backend
...
```

### Merge the repositories

Finally, merge all those remotes into the combined project. Simply repeat this step for every remote
you want to merge. At this point it pays off to prepare the repositories in order to avoid any merge
conflicts right away.

```
⦁ project/project : master $ git merge -s ours --no-commit --allow-unrelated-histories frontend/master
Automatic merge went well; stopped before committing as requested
⦁ project/project : master|MERGING $ git read-tree --prefix= -u frontend/master
⦁ project/project : master +|MERGING $ git commit -a
[master 96012d4] Merge remote-tracking branch 'frontend/master'
```

You will end up with a repository where history looks somewhat like this:

```
⦁ project/project : master $ git log --graph
*   7a53ff5 2019-02-19 11:28:15 +0100 N Merge remote-tracking branch 'backend/master' (HEAD -> master) [Anton Semjonov]
|\
| * f89bfa3 2019-02-18 16:57:07 +0100 N prepare backend for merge (backend/master) [Anton Semjonov]
| * ea8a4f7 2018-09-18 15:19:16 +0200 N update scripts [Anton Semjonov]
| [...]
*   96012d4 2019-02-19 11:27:49 +0100 N Merge remote-tracking branch 'frontend/master' [Anton Semjonov]
|\
| * c777b42 2019-02-18 16:57:56 +0100 N prepare frontend for merge (frontend/master) [Anton Semjonov]
| * e3812e2 2019-01-18 22:35:30 +0100 N korrigiere Leonhard [Anton Semjonov]
| [...]
* b0605af 2019-02-19 11:25:36 +0100 N prepare combined repository for project [Anton Semjonov]
```
