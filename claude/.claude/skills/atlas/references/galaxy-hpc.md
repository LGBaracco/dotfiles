# galaxy + JSC/JURECA HPC

galaxy = shpc + Lmod + Apptainer wrapper that ships atlas and its companion tools as one container on JSC systems. Repo `jugit.fz-juelich.de/galaxy/galaxy`; local copy `$GALAXY_SRC` (see `../local-setup.md`). Concrete paths, account, user: `../local-setup.md`.

## Activate (every new shell / job)
```bash
source $GALAXY_ROOT/init.sh     # module purge; Stages/2025 + GCC + shpc; module use views; APPTAINER_CACHEDIR/TMPDIR; SLURM_MPI_TYPE=pspmix|pmix; aliases
module load atlas               # container wrappers on PATH
atlas-dev                       # optional: bind $GALAXY_ROOT/code/* dev checkouts over the container's packages (alias for eval $(atlas_bind_dev))
```
`init.sh` wipes loaded modules (`module purge`). If `~/.singularity-hpc/settings.yml` is missing it runs first-time setup (`shpc config inituser`, `galaxy_setup` → asks for the jugit registry username).

## Commands after `module load atlas` (each runs inside the container)
| command | what |
|---|---|
| `atlas` | the CLI (cli.md) |
| `b3` | brain3d: AnchorPoints conversion/processing/analysis (companions.md) |
| `samplestuff` | sample/anchor-point utilities, e.g. `ann2anchor` (companions.md) |
| `anndb` | annotation database (MicroDraw/SectionTracer) |
| `colin` | Colin27 ↔ section transforms |
| `atlas3d`, `tseg`, `meshio` | 3D/graph atlas, tissue segmentation, mesh I/O |
| `python`, `python3`, `ipython`, `pip`, `snakemake`, `tensorboard`, `h5ls`, `h5dump`, `h5diff`, `h5repack`, ... | container tools; atlas, brain3d, atlaslib, ... importable |
| `atlas-exec CMD...`, `atlas-shell`, `atlas-run`, `atlas-container` (prints .sif path), `atlas-inspect-deffile` | raw container access (shpc) |
| `atlas_clone_dev` | clone dev packages into `$GALAXY_ROOT/code/` (some repos need access requests) |
| `atlas-dev` / `atlas-nodev` | bind / unbind `code/*` checkouts (sets `APPTAINER_BIND`/`PYTHONPATH` via `atlas_bind_dev`/`atlas_unbind_dev`) |
| `upatlas`, `upatlaslib` | `git pull` the dev checkout (`galaxy_update_dev <pkg>`) |
| `galaxy_update` / `galaxy_update_shpc` | pull galaxy / the shpc registry |
| `shpc install atlas` | install/upgrade the container (new tag from `shpc-registry/atlas/container.yaml`) |
| `atlas_create_jupyter_kernel` | Jupyter kernel `atlas` (below) |
| `viddy` | modern `watch` (e.g. `viddy -n 30 squeue --me`) |
Env knobs for every wrapper: `SINGULARITY_OPTS`, `SINGULARITY_COMMAND_OPTS` (e.g. `-B /extra/path`), `APPTAINER_BIND`.

### Which atlas runs
- Without `atlas-dev`: the container's packages (`atlas` v1.2.16 container, PyTorch 2.8, CUDA 12.9, NCCL 2.27).
- With `atlas-dev`: `$GALAXY_ROOT/code/<pkg>` checkouts. Their commit can differ from the local source the references describe (`git -c safe.directory='*' -C $GALAXY_ROOT/code/atlas log -1`). Features newer than the JURECA checkout need `upatlas` first.
- Container internals: `/atlas/bin/*`, `/usr/local/bin/<tool>`. Custom shpc template (`shpc-templates/singularity.sh`) uses `apptainer run --runscript-timeout 3m` and a no-op NVIDIA entrypoint.

## Slurm inside the container
`shpc-templates/snippets/slurm.sh` bind-mounts `sbatch/srun/squeue/scancel/scontrol/sacct`, munge, ParaStation, lua and jutil into the container and adds the `slurm` user → `srun atlas ...` and Slurm commands from container Python just work. `PMIX_SECURITY_MODE=native`; `SLURM_MPI_TYPE` set by `init.sh`.

## MPI layout for atlas GPU commands (`dl train|predict|segment|predict-points`, `data batch generate`)
- Per node: ranks with `LOCAL_RANK < len(CUDA_VISIBLE_DEVICES)` = GPU masters (one per GPU), the rest = CPU data-loading slaves (`CUDA_VISIBLE_DEVICES=""` for them).
- Need ≥1 slave per master (`--slaves-per-master`), plus 1 test slave when `test_interval` is set → never fewer than 2 ranks per GPU. Standard JURECA-DC layout: `--tasks-per-node=64 --threads-per-core=2` + `srun --cpus-per-task 4` = 4 masters + 60 slaves per 4-GPU node.
- Set `CUDA_VISIBLE_DEVICES="0,1,2,3"` explicitly in jobs (unset → atlas assumes 1 GPU/node).
- `dl train --distribute` = DDP over all masters of all nodes (batch_size in the config is per master); without it, several experiments are trained in parallel, one per master.
- Single process (no `srun`) = sequential; fine for CPU smoke tests on a login node.

## sbatch anatomy (templates in `../templates/`)
```bash
#SBATCH --account=<account> --partition=<gpu partition> --gres=gpu:4
#SBATCH --tasks-per-node=64 --threads-per-core=2
#SBATCH --output=<name>-out.%j --error=<name>-err.%j
#SBATCH --signal=TERM@120          # atlas snapshots before timeout (snapshot_before_slurm_timeout_seconds=600)
source $GALAXY_ROOT/init.sh; module load atlas; eval $(atlas_bind_dev)   # optional dev bind
export CUDA_VISIBLE_DEVICES="0,1,2,3" DMS_TIMEOUT=300
export NCCL_IB_TIMEOUT=200 UCX_RC_TIMEOUT=16s NCCL_IB_RETRY_CNT=30 NCCL_IB_RETURN_ASYNC_EVENTS=0 NCCL_SOCKET_NTHREADS=4   # IB flakiness fixes
srun --cpus-per-task 4 atlas dl train <exp> --distribute
```
- `--nodes` and `--time` on the command line: `sbatch --nodes=4 --time=06:00:00 train.sbatch <exp>`.
- Training resumes from the latest checkpoint automatically → wrap `srun` in a retry loop (link flips) and resubmit the same command after a timeout.
- `dms` (dead man's switch, enabled by default in `dl train`) kills a hung job after `DMS_TIMEOUT` seconds without progress.
- Logs: Slurm `<name>-{out,err}.<jobid>` in the submit directory; atlas per-rank logs in `<run>/log/`, diagnostics JSON in `<run>/log/diagnostics/`, TensorBoard in `<run>/models/tensorboard/` (`atlas exp tensorboard <runs>`).

## Interactive / quick tests
- Devel partition allocation: `salloc --account=<account> --partition=<gpu devel partition> --nodes=1 --gres=gpu:4 --time=01:00:00`, then (galaxy sourced) `srun --ntasks=8 --cpus-per-task=4 atlas dl predict-points <exp> pts.hdf5 --max-points 100 --name smoke`.
- Login-node CPU smoke test (no srun): `atlas dl predict-points <exp> pts.hdf5 --max-points 1 --batch-size 1 --name smoke` (no `--amp`).
- Config/data check without training: `atlas dl train <exp> --dry`, `--fake-data`, or `atlas data batch generate <run>/config.py out/ train --batches 2` then `atlas data batch show out/*.hdf5 --output png/`.

## Monitoring
`squeue --me`, `sacct -j <id> --format=JobID,State,Elapsed,MaxRSS,ExitCode`, `scontrol show job <id>`, `viddy squeue --me`, `tail -f <name>-out.<id>`, `grep -iE "error|traceback" <name>-err.<id> | head`. Per-rank atlas logs `<run>/log/*_master_*.log`.

## Data staging / I/O
- HDF5 `split` driver files: `FileParams.h5py_args={"driver": "split", "rdcc_nbytes": ...}`; chunk cache must hold ≥1 chunk or reads go row by row.
- Zarr to RAM: `ImageProviderParams(use_ram_cache_for_zarr_files=True)` (stage dir `/dev/shm/$SLURM_JOB_ID`), or `srun --ntasks-per-node=1 atlas data stage-zarr <paths>` before training.
- `/p/scratch` is purged periodically; keep inputs you need on project storage.
- Importing atlas creates `/dev/shm/atlaslib-zarrjson-cache/<host>` (fine on compute nodes).

## Jupyter
- `atlas_create_jupyter_kernel` → `~/.local/share/jupyter/kernels/atlas/kernel.sh`: sources galaxy, `module load atlas`, `atlas_bind_dev` (dev checkouts!), binds host `~/.local/lib/pythonX.Y/site-packages` into the container, runs `atlas-exec python -m ipykernel`.
- The kernel runs where JupyterLab runs: on JupyterJSC pick a compute partition (GPU) at launch for GPU work; a login-node session has no GPU.
- Own JupyterLab on a compute node + SSH tunnel: see `../local-setup.md` (`tunnel <node>`).

## One-time setup (per user, JSC)
1. JuDoor → "Request access to restricted software" → container runtime (takes time to propagate).
2. `jutil env activate -p <project> -A <account>`; easybuild dir `mkdir -p $PROJECT/$USER/easybuild && ln -s $PROJECT/$USER/easybuild`.
3. `source galaxy/init.sh` → `galaxy_setup` (registry login), optional `galaxy_init_software` (git-annex + datalad modules under `$GALAXY_ROOT/software/`).
4. `shpc install atlas`; optional `atlas_clone_dev` + `atlas-dev`; `atlas_create_jupyter_kernel`.
5. Optional `.atlas.json` from the container: `[[ -f ~/.atlas.json ]] || atlas-exec cp /atlas/.atlas.json ~/.atlas.json` (README's version has the `if` inverted).

## datalad provenance (optional)
`galaxy_init_software` installs `git-annex/latest` and `datalad/latest` modules (`module use $GALAXY_ROOT/software/modules`). Pattern (`galaxy/scripts/compute_metrics_test_transfer.sh`): `datalad run --explicit --output metrics.hdf5 atlas dl evaluate-points ...`.
