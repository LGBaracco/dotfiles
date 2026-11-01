---
name: atlas
description: Use atlas (ATLaS, Christian Schiffer's PyTorch+MPI deep-learning framework for histological brain sections), the galaxy container toolbox (b3/brain3d AnchorPoints, samplestuff, anndb, colin, atlaslib) and JURECA/JSC Slurm jobs. Covers experiments and runs, writing config.py (all training modes, samplers, data sources, models, losses, augmentation), training, dl predict / predict-points feature extraction, evaluation, img/reg/data CLI tools and the Python API. Use before running, writing or debugging any atlas, b3, samplestuff, anndb or galaxy command, atlas config, or JURECA sbatch job.
---

# atlas + galaxy + JURECA

## What is what
- **atlas** = "Automatic Tissue Labeling System": trains/applies CNNs and ViTs on 2D histological sections (HDF5/Zarr/TIFF image pyramids). Everything is an *experiment folder* with a `config.py`, driven by the `atlas` CLI. Not siibra, not a data-download client.
- **galaxy** = shpc + Lmod + Apptainer wrapper on JSC machines: `module load atlas` gives `atlas`, `b3`, `samplestuff`, `anndb`, `colin`, `python`, ... all inside one container, Slurm usable from inside.
- **Companions** (in the container, dev checkouts in `$GALAXY_ROOT/code/`): brain3d (`AnchorPoints`, `b3`), samplestuff, annotation_db (`anndb`), colin, atlaslib (image I/O, `BoundingBox`), typhon/atlasmpi (MPI), dms (dead man's switch), rambo (RAM staging).
- Personal values (paths, account, how to reach JURECA, versions): **`local-setup.md`** — read it before touching JURECA paths or jobs.

## Two environments
| | this machine | JURECA (galaxy container) |
|---|---|---|
| use for | reading source + references, writing configs/scripts | anything touching data, GPUs, Slurm |
| atlas | source only (`$ATLAS_SRC`), not installed → don't run `atlas`/`atlas --help` | `module load atlas` (+ `atlas-dev` for dev checkouts) |
| access | — | user runs commands and pastes output; files via sshfs mount (`local-setup.md`) |

## Router: read only the file you need
| task | read |
|---|---|
| look up / run any `atlas` command (65: dl, exp, img, reg, data, shell) | `references/cli.md` |
| write or edit a `config.py` (TrainParams, modes, samplers, augmentation, LR, finetune/freeze) | `references/config.md` + `templates/config_minimal.py` |
| pick a model, loss, SSL method, optimizer, metric | `references/models-losses.md` |
| data sources, `InputOutputMapping`, sample-file formats | `references/data-sources.md` |
| features for points, dense prediction, evaluation, reading outputs | `references/prediction.md` |
| use atlas from Python / Jupyter (runs, reports, ImageProvider, batches, metrics, polygons, laplace) | `references/python-api.md` |
| galaxy commands, modules, dev binds, MPI rank layout, sbatch, Jupyter, monitoring | `references/galaxy-hpc.md` + `templates/*.sbatch` |
| `b3`, `samplestuff`, `anndb`, `colin`, AnchorPoints, atlaslib/typhon/dms/rambo | `references/companions.md` |

## Core model (enough for most tasks)
```
<exp>/                       # YYYY_MM_DD_<name>  (atlas exp new NAME [--config f.py])
├── config.py                # template; edits here do NOT affect existing runs
├── active_run -> YYYY_MM_DD_runNN
└── YYYY_MM_DD_runNN/        # atlas exp run new <exp>   |   atlas exp run copy <run> --dst <exp>
    ├── config.py            # the one actually used
    ├── models/training_state_NNNN.pt, active_model -> ...   # checkpoint dict, weights under "model"
    ├── log/                 # per-rank logs, diagnostics/
    └── results/predictions/[<name>/]...                       # dl predict / predict-points output
```
- A folder argument resolves to: itself if it is a run (`*_runNN`, `exp/active_run` works) → `<exp>/active_run` → newest run.
- Model used by predict/predict-points: `models/active_model`, else newest `training_state_*.pt` (`atlas exp model active <file>` to pin).
- `config.py` defines `make_training_parameters(**kw) -> config.TrainParams` and `make_network(**kw) -> nn.Module`; it runs on every MPI rank and also at prediction time.

## Most-used commands (JURECA, after `source $GALAXY_ROOT/init.sh && module load atlas`)
```bash
atlas exp new NAME --config cfg.py && atlas exp run new YYYY_MM_DD_NAME        # new experiment + run
atlas exp run copy <src_run> --dst <exp>                                       # reuse a trained model, no config writing
sbatch --nodes=4 --time=06:00:00 train.sbatch <exp>                            # → srun atlas dl train <exp> --distribute
srun atlas dl predict-points <exp> pts.hdf5 --output-configuration feat:encoder --amp --name X   # per-point features
atlas dl predict <exp> --slices 20:1201-1210 && atlas dl evaluate <exp> --write-report           # dense maps + metrics
atlas dl evaluate-points out/*.hdf5 f1,accuracy metrics.h5                     # point metrics
atlas img info FILE.hdf5                                                       # inspect any image file
atlas exp run list --experiment-folder <exp>;  atlas exp tensorboard <runs>    # overview
atlas data batch generate <run>/config.py out/ train --batches 2               # check the data pipeline without training
```

## Top gotchas
1. `Params` swallows typos/misplaced kwargs silently and returns `None` for missing fields → double-check names against config.md.
2. `config.ImageProviderParams.FILE_PARAMETERS` is one shared class-level dict, resolved from `.atlas.json`/`ATLAS_*` at import.
3. `batch_size` is per GPU master: `TOTAL // NUM_MASTERS` with an assert. Default `distributed_learning_rate_scaling=True` multiplies lr by #GPUs.
4. GPU commands need ≥2 MPI ranks per GPU (masters + data-loading slaves); set `CUDA_VISIBLE_DEVICES="0,1,2,3"` in jobs.
5. HDF5 sample files: `SamplerParams(file_sampler_samples_key="boxes")` (default `"samples"` is for JSON).
6. Freezing done in `weight_init_func` is lost on resume (resume > finetune > weight_init_func); freeze in `post_weight_init_func`.
7. `predict-points`: `--output-configuration` is ONE comma-separated value; default split is **train**; output files are overwritten; no `--model` option.
8. `dl predict` without `--model` needs `models/active_model`.
9. Destructive without prompt: `exp run clean`, `exp run compress` (no `--keep`), `exp model reduce --delete`, `data hdf5 *`.
10. Broken/stale: `dl simulate`, `distance` sampler, several trainers' autocast (see config.md §4), shapely-2/matplotlib-3.9 plotting commands (`exp vis area`, `img show-contours`, `exp compare` images).
11. JURECA's dev checkout may be older than `$ATLAS_SRC` (`local-setup.md` lists missing features) → `upatlas` first.

## Working rules (token budget)
- Load only the routed reference; they are complete for atlas `v0.3.0-6-gc64050cf`. `file:line` refs are relative to `$ATLAS_SRC/atlas/`; if a line moved, `rg -n "<symbol>"` in that one file instead of re-exploring.
- Never run `atlas --help` locally; read `references/cli.md`.
- On the sshfs mount: `timeout 30`, `ls` one level at a time, read specific files, never recurse.
- Before computing anything, check whether outputs already exist (`results/predictions/`, other users' runs).
- `sbatch`, `scancel`, writes to shared JURECA folders: only after the user confirms. Read-only checks (`squeue`, `sacct`, `ls`, `img info`) are fine to suggest.
- Prefer existing CLI tools (`atlas`, `b3`, `samplestuff`) over new code; for job scripts start from `templates/`.
