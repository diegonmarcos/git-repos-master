# repo_master

The index of every repository this account owns — 26 of them, grouped, with a
`clone.sh` that pulls down whichever ones you want on this machine.

```
./clone.sh                        # what exists here, what does not
./clone.sh unix notes             # clone those two
./clone.sh --group b_data_science # clone a whole group
./clone.sh --all                  # everything
```

No project code lives here. `repos.json` is the registry and `clone.sh` reads
it and nothing else; the group directories hold committed relative symlinks out
to the clones. A link that dangles is a repo you have not cloned yet — that is
the index working.

`cloud-master` is the same idea narrowed to the cloud project. See
[`a0_docs/README.md`](a0_docs/README.md) for how the two relate, why this is
not submodules, and what each directory is for.
