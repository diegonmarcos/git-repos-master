# a0_docs — what this repo is

`repo_master` is the **index of every repository this account owns**: one place
that knows what exists, and a tool to pull down whichever of them you actually
want on this machine.

It holds no project code. Two files carry the whole thing:

- `repos.json`  the registry — name, group, url, private, one-line purpose
- `clone.sh`    clone what you want, symlink it into view

```
./clone.sh                        # what exists here, what does not
./clone.sh unix notes             # clone those two
./clone.sh --group b_data_science # clone a whole group
./clone.sh --all                  # everything
./clone.sh --link                 # relink whatever is already cloned
```

## Groups

Four, and the prefixes are the sort order, not decoration:

| group | | |
|---|---|---|
| `2_vault/`        |  1 | Secrets (sops/age). Numbered so it sorts ahead of the lettered groups — it is the one repo whose absence breaks the others. |
| `a_cloud/`        | 11 | The cloud project: infra, services, data, front-end, and the tooling built for it. |
| `b_data_science/` |  3 | Machine-learning and data-science work. |
| `y_others/`       | 11 | Coursework, experiments, forks, personal. `y_` so it sorts **last**. |

## repo_master and cloud-master

Two indexes, one of which is a subset of the other:

| | `repo_master` | `cloud-master` |
|---|---|---|
| covers | all 26 repositories | the cloud project (12) |
| layout | every repo under its group | the cloud repos at the **root**, vault under `2_vault/` |
| for | "what do I own, where is it" | working on the cloud project |

The overlapping entries must agree field for field. `repo_master` is the
superset and the place to add a new repository; if it belongs to the cloud
project, add it to `cloud-master/repos.json` as well.

`cloud-master` drops the group directory for its eleven cloud repos because
they are the whole of that index — an `a_cloud/` wrapper there distinguished
nothing. Here the groups do real work, so they stay.

## Why symlinks and not submodules

A submodule pins a commit and wants `--recursive`. Here that meant
`repo_master` containing `cloud` containing `repo_master` — an unterminating
recursive clone — private repos breaking `init` for anyone without those
credentials, and 26 repositories dragged along to read one file. This repo
began that way and the submodules were dissolved for exactly those reasons.

An index of working clones is a different thing from a pinned build input, and
this is the former.

The links are **relative** (`../../<name>` from a group directory) and
**committed**. Absolute would not survive the trip: git stores a symlink's
target verbatim, so a committed `/home/diego/git/cloud-unix` resolves on exactly one
machine and dangles everywhere else — the same failure `.mcp.json` had as a
link to `/home/diego/.mcp.json`. Relative has no such dependency: clone the
repos as siblings anywhere (`$CLOUD_GIT_BASE`, `~/git`, `/srv`, a container)
and every link resolves.

A link to a repo you have not cloned dangles, deliberately. That **is** the
index: `ls y_others/` shows every repo in the group, and the broken ones are
the ones you do not have yet. `./clone.sh --list` spells it out.

## Layout

```
0_git/     src/ dist/   gitconfig, gitattributes, gitignore, hooks/
0_apps/    src/ dist/   claude, vscode, obsidian dotfiles + root/mcp.json
9_others/  src/ dist/   shared libs + build.sh
a0_docs/                this
a0_tasks/               what is being done
2_vault/  a_cloud/  b_data_science/  y_others/     the index itself
```

`0_`/`1_`/`2_` is config — the dotfile and env tier. `a_`/`b_` is the tree.
Same convention as every other repo in the fleet; `./9_others/build.sh` is the
same builder.
