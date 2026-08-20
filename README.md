# repo_master

The index of every repository this account owns — 27 of them, grouped, with a
`clone.sh` that pulls down whichever ones you want on this machine. The 28th is
this repo; it is the index, so it has no entry pointing at itself.

| group | what |
|---|---|
| `2_vault` | secrets (sops/age) — sorts first, everything else needs it |
| `a_cloud` | the cloud project: infra, services, data, devices, tooling |
| `b_front` | the front-end: site, content, assets, experiments |
| `c_gh` | account-level GitHub repos (the profile README) |
| `d_lecole` | 42 coursework — clones sit in `~/git/lecole-42/`, see `path` in `repos.json` |

```
./clone.sh                        # what exists here, what does not
./clone.sh cloud-unix cloud-notes # clone those two
./clone.sh --group d_lecole       # clone a whole group
./clone.sh --all                  # everything
```

No project code lives here. `repos.json` is the registry and `clone.sh` reads
it and nothing else; the group directories hold committed relative symlinks out
to the clones. A link that dangles is a repo you have not cloned yet — that is
the index working.

`cloud-master` is the same idea narrowed to the cloud project. See
[`a0_docs/README.md`](a0_docs/README.md) for how the two relate, why this is
not submodules, and what each directory is for.
