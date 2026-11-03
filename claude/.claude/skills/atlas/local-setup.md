# Local setup (Lorenzo) — the only file with personal values

## Placeholders used in the references
| placeholder | value |
|---|---|
| `$ATLAS_SRC` | local clone of atlas; **path depends on the host**: the project's `AGENTS.md` names it per host, else ask the user. References' `file:line` match `v0.3.0-6-gc64050cf` (2026-10-30) |
| `$GALAXY_SRC` | local clone of the galaxy repo; host-dependent like `$ATLAS_SRC` (may not exist) |
| `$GALAXY_ROOT` | JURECA `/p/project1/cjinm16/baracco1/home_ext/galaxy` |
| `<account>` | `jinm16` (budget; data project `cjinm16`, `jutil env activate -p cjinm16 -A jinm16`) |
| `<gpu partition>` | `dc-gpu` (JURECA-DC, 4 GPUs/node); tests: `dc-gpu-devel` |
| `<email>` | `l.baracco@fz-juelich.de` |
| JSC user | `baracco1` |

If this host has no local clone: read the same code on the mount (`$GALAXY_ROOT/code/atlas`, see below) or clone `https://jugit.fz-juelich.de/inm-1/bda/software/analysis/atlas/atlas.git` (SSH: `git@jugit.fz-juelich.de:...`; HTTPS needs a token).
Env for a local clone: `uv sync --python 3.11` in the clone (fallback `uv venv --python 3.11 && uv pip install -e .`; never plain pip).
atlas's own jugit deps are HTTPS URLs → for that command only: `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=url.git@jugit.fz-juelich.de:.insteadOf GIT_CONFIG_VALUE_0=https://jugit.fz-juelich.de/`.
Keep `.venv/` and `uv.lock` out of atlas commits (`.git/info/exclude`).

## Reaching JURECA from this machine
- SSH needs interactive 2FA (`Permission denied (keyboard-interactive)` in batch mode) → Claude cannot run remote commands. The user runs them on JURECA and pastes output, or commits there and pulls here.
- File access: the user runs `mju` (fish alias) = `sshfs -o AddressFamily=inet -o IdentityFile=~/.ssh/id_jureca -o follow_symlinks,reconnect,ServerAliveInterval=15 baracco1@jureca.fz-juelich.de:/p /mnt/jureca/`.
  JURECA `/p/<x>` = local `/mnt/jureca/<x>` (e.g. `$GALAXY_ROOT` = `/mnt/jureca/project1/cjinm16/baracco1/home_ext/galaxy`). Check with `timeout 5 ls /mnt/jureca`.
  sshfs is slow: `timeout 30` on every command, `ls` one level at a time, never recurse/`rg` a whole tree, `git -c safe.directory='*'`.
- Interactive login: `ssh -4 -i ~/.ssh/id_jureca baracco1@jureca.fz-juelich.de`.
- Jupyter tunnel to a compute node: `tunnel <node>` (fish function: `ssh -4 -i ~/.ssh/id_jureca -N -L 8888:<node>:8888 baracco1@jureca.fz-juelich.de`).

## State on JURECA (checked 2026-11-01)
- Galaxy lines in JURECA `~/.bashrc` are commented out → `source $GALAXY_ROOT/init.sh` manually (it also purges modules).
- Done once: JuDoor container access, `galaxy_setup`, `shpc install atlas` (container `v1.2.16-amd64`: PyTorch 2.8, CUDA 12.9), `atlas_create_jupyter_kernel`, dev checkouts in `$GALAXY_ROOT/code/`: annotation_db, atlas, atlas3d, atlaslib, atlasmpi, brain3d, colin, dms, meshio, rambo, samplestuff, siibra-python, tseg, typhon.
- `$GALAXY_ROOT/code/atlas` HEAD = `c745ad92` (2026-09-30) — **older than `$ATLAS_SRC`**. Missing on JURECA until `upatlas` (+ `atlas-dev`): `atlas exp model gitignore|gitadd|reduce`, `dl predict-points --output-adapter`, contrastive deep supervision (`contrastive_deep_supervision_weights`, `DeepSupervisionContrastiveLoss`). Re-check with `git -c safe.directory='*' -C /mnt/jureca/project1/cjinm16/baracco1/home_ext/galaxy/code/atlas log -1 --format='%h %ci'`.
- `code/annotation_db/db/anndb*` snapshot dirs are empty submodules → `git submodule update --init db/<snapshot>` before using a snapshot.
- Job logs land in the submit directory as `<name>-{out,err}.<jobid>`.
