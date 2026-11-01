# atlas CLI reference (all 65 commands)

`file:line` paths are relative to the atlas package root `$ATLAS_SRC/atlas/` (see `../local-setup.md`), at atlas `v0.3.0-6-gc64050cf`.
Short names: **C** = `cli/atlas_cli.py` (click decorators), **DL** `cli/dl.py`, **EX** `cli/exp.py`, **IM** `cli/img.py`, **DA** `cli/data.py`, **RG** `cli/reg.py`.
`C:N → DL:M` = decorator at C line N, implementation at DL line M. If a line moved, `rg -n "def <name>|\"<command>\"" $ATLAS_SRC/atlas/cli`.

Groups: [dl](#dl) (7) · [exp](#exp) (22) · [img](#img) (16) · [reg](#reg) (7) · [data](#data) (10) · [shell](#shell) (3) · [cross-cutting gotchas](#gotchas)

## Wiring (read once)
- Entry `atlas = atlas.cli.atlas_cli:cli` (`pyproject.toml:84`). No global options, no `--version`; `--verbose` is per command.
- Every call imports MPI (`atlasmpi`, else `mpi4py`) and reads `.atlas.json`/`ATLAS_*` (warns if absent). An MPI library is needed even for serial use.
- Any command can run under `srun`; `COMM_WORLD.size` sets parallelism. Two patterns:
  1. **Master/slave** (`dl train|predict|segment|predict-points`, `data batch generate`): per node, ranks with `LOCAL_RANK < len(CUDA_VISIBLE_DEVICES)` are GPU masters (unset → assumes 1 GPU), the rest are CPU data loaders with `CUDA_VISIBLE_DEVICES=""`. Needs ≥ `--slaves-per-master` (default 1) slaves per master → use ≥2 ranks per GPU (JURECA jobs use 16/GPU). GPU = `cuda:LOCAL_RANK`.
  2. **Round-robin** of files/sections over ranks (most `img`/`reg`/`data` tools).
- Folder argument → run (`experiments/files.py:473`): basename matches `*YYYY_MM_DD_runNN*` → used as is (`exp/active_run` works); else `<exp>/active_run`; else last `*_runNN`; else error.
- Config = always `<run>/config.py`. Editing `<exp>/config.py` after `exp run new` has no effect.
- Model: `get_latest_training_state` = `models/active_model` else highest `training_state_NNNN.pt`; `get_latest_model` = `active_model` else `model_NNNN.hdf5` (old TF format).
- Run layout: `config.py`, `models/` (`training_state_*.pt`, `active_model`, `tensorboard/`, `timings/`, `probability_distributions/`), `log/` (`<prefix>_master_<rank>.log`, `_slave_`, `diagnostics/`), `results/{predictions,activations,overview,reports,plots,hdf5,png}`.
- Argument formats: `SLICES` = `1201,1261-1270,1300-1400-10` (`,`/`;`, `from-to-step`); with brain `20:1201,B21:1261-1270` (`experiments/click.py:9`). `BoundingBox` = `cx:..,cy:..,h:..,w:..,s:..` or `fx:..,fy:..,tx:..,ty:..,s:..` (`click.py:84`). "Patterns" = a concrete example filename whose 4-digit section (and `B##`) is substituted (`atlaslib.files.get_filename_from_template`).
- Env: `ATLAS_CONFIG_FILE`, `ATLAS_<KEY>` (see config.md §constants), `CUDA_VISIBLE_DEVICES` (= GPUs/node = masters), `SLURM_JOB_ID`.
- Resource class: **GPU** `dl train|predict|segment|predict-points` (CPU fallback). **MPI-parallel CPU**: `img ann2hdf5 tif2hdf5 png2mask png2hdf5 threshold mask2contours show-contours overlay png mask2laplace transform`, `reg convert verify feature-based consecutive`, `data batch generate`, `data batch show` (save mode). **Serial**: the rest; `dl evaluate[-points]` repeat all work on every rank under MPI.
- Need a display unless an output option is given: `img show|overlay|show-contours`, `exp vis *`, `exp test visualize`, `exp compare`, `data batch show`.

## dl
- **`dl train EXP...`** C:38 → DL:200. Train latest/active run. `--distribute` (all masters train each folder together; without it folders are split over masters), `--slaves-per-master 1`, `--fake-gpus N`, `--dry`, `--fake-data`, `--fake-samples`, `--cache-mode file|memory` + `--files-to-cache FILE` (lines `path:dataset`), `--quiet/--super-quiet`, `--log-limit-cpus`, `--dms/--no-dms` (dead-man switch, skipped if `dms` missing), `--diagnostics/--no-diagnostics` (default ON; help text wrong), `--log-dir-per-node` (with `--distribute`), `--shm-diagnostics-tar`, `--profile`. Resumes from the run's latest `training_state` automatically. Writes `models/`, `log/`, `log/diagnostics`.
- **`dl predict EXP...`** C:211 → DL:497. Dense whole-section prediction on the config's **val** split. `--output-spacing 64`, `--model FILE`, `--slices SLICES(brain)`, `--save-argmax`, `--overwrite` (else existing sections skipped), `--write-activations` + `--activations-output-spacing` + `--activation-layers a,b`, `--fake-data`, `--profile`. Out: `results/predictions/`. GOTCHA: without `--model` needs `models/active_model` (pure-torch runs only have `.pt` → crash on empty unpack); `--cache-mode memory` broken (DL:582). See prediction.md.
- **`dl evaluate EXP...`** C:344 → DL:746. Post-processes `dl predict` output; each flag triggers one writer: `--write-overview` (results/overview), `--write-report` (reports), `--write-confusion-matrix`, `--write-training-statistics` (plots), `--pred-to-hdf5`/`--embedded-pred-to-hdf5` (hdf5), `--pred-to-png`/`--embedded-pred-to-png` (png), `--write-embedded-activations` [+`--force-...`], `--write-image-activations` + `--image-activations-cmap`. Also `--dataset-prefix`, `--output-prefix`, `--output-spacing 64`, `--metrics-spacing 64`, `--write-coordinates/--dont-...`. GOTCHA: no flag → does nothing. CPU, not MPI-aware.
- **`dl evaluate-points ANCHOR_POINTS... METRICS OUTPUT_FILE`** C:514 → DL:876. METRICS = one comma string of `accuracy,f1,precision,recall,iou`. `--labels-file JSON` (fix label order), `--prediction-key classes`, `--labels-key labels`, `--experiment-name` (adds `name` column). Combined confusion matrix over all files → per-label pandas table, `to_hdf(key="metrics")` (needs PyTables). Input = predict-points output with `classes` + `labels` features.
- **`dl segment WORKING_DIR MODEL OUTPUT_PATTERN`** C:575 → DL:925. Like predict but explicit `.pt` model + output pattern; argmax into `WORKING_DIR/tmp_segment/`, then embedded segmentations to OUTPUT_PATTERN. `--output-spacing`, `--output-prefix`, `--slices`, `--batch-size`, `--write-coordinates`. GOTCHA: config image provider must define histology, annotations and bg_cor_wm_segmentation channels (else KeyError).
- **`dl predict-points EXP POINTS...`** C:681 → DL:1372. Per-point features/predictions. Full details: prediction.md. Key: `--output-configuration name:attr,name:@hook:mod.path` (ONE comma value) XOR `--output-adapter FILE[:FACTORY]`; `--name`, `--output-dir`, `--split` (default **train**), `--batch-size`, `--amp`, `--max-points`, `--subsample-points`, `--sample-attr k:v`, `--enable-transformations`, `--include-input/--include-output`, `--strict-weights`, `--stochastic-forward-passes N` + `--stochastic-forward-seed`. No `--model`: use `exp model active`. Overwrites existing output.
- **`dl simulate`** C:876 → DL:1183. BROKEN (`NotImplementedError`, TF leftover).

## exp
- **`exp new NAMES...`** C:947 → EX:8. Makes `YYYY_MM_DD_<name>/` (local date). `--config FILE` (copied to `config.py`), `--target-directory` (must exist), `--experiment-format`. Existing folders skipped.
- **`exp run new EXP...`** C:997 → EX:60. Copies `<exp>/config.py` to `<exp>/<UTC date>_runNN/config.py` via `setup_config` (fills `"$MEAN_<CH>"`, `"$STD_<CH>"`, `"$CLASS_WEIGHTS"`, `"$DISTANCE_RADIUS_<SPLIT>"`, `"$VERSION_ATLAS"` tokens), sets `active_run`. `--count N` (N runs, never sets active, no `--name`), `--name` (extra symlink, relative to CWD → can break), `--set-active/--dont-set-active`. GOTCHA: next number = active+1, can overwrite an existing same-day run's config.
- **`exp run copy SRC --dst EXP`** C:1043 → EX:127. Copy a run (config + `models` symlink, or `--copy-models`) into an existing experiment, `--set-active`, adds `copied_from` link. Fastest way to reuse a trained model.
- **`exp run fix RUNS...`** C:1075 → EX:177. Re-run `setup_config` in place (old runs).
- **`exp run active RUN`** C:1092 → EX:205. Point `<exp>/active_run` at RUN (silently exits 0 if name doesn't match the run regex).
- **`exp run list [--experiment-folder .]`** C:1105 → EX:223. Table: name, active, config, models, logs, results ("results" column actually checks `log/`).
- **`exp run clean RUNS...`** C:1121 → EX:268. DESTRUCTIVE, no prompt: rmtree `log/ models/ results/` + bundle.
- **`exp run combine RUNS... OUTPUT`** C:1140 → EX:307. Collect `*.png|jpg` by basename across runs into tiled grids (dpi 700). OUTPUT must exist.
- **`exp run compress RUNS...`** C:1165 → EX:350. `--logs --models --tensorboard --probability-distributions` → `<dir>[_suffix].tar.gz`, originals DELETED unless `--keep`; `--no-compress` (.tar), `--suffix`. No flags → nothing.
- **`exp model active MODEL`** C:1226 → EX:430. `models/active_model` → MODEL (relative link; must sit inside a run; link written next to the resolved file).
- **`exp model gitignore PATH [--none]`** C:1239 → EX:533. Write `models/.gitignore` excluding all checkpoints except active (or given) model.
- **`exp model gitadd PATH`** C:1255 → EX:560. Add `!model` line.
- **`exp model reduce PATH [-n/--retain N] [--delete]`** C:1270 → EX:611. PATH = experiment (its active/latest run), run, `models/` dir or a model file (`_resolve_model_target` EX:460; same for `gitignore`/`gitadd`). If `models/` is a symlink (`exp run copy`), the source run's files are deleted. Free disk: keep active, git-included and N evenly spaced iterations (+latest), delete other `training_state_*.pt`/`model_*.hdf5`. DRY RUN unless `--delete`; prints GiB freed.
- **`exp test create OUT BRAIN SLICE_NO LABELS...`** C:1294 → EX:676. Build a test-set JSON `test_set_B##_####_<labels>.json` from a weighted sampler on constants paths (`.atlas.json`). `--size 500`, `--seed`, `--area-mode whole|distance` (+`--congruent-sections`), `--desired-ratio`, `--distance-radius auto|f`, `--distance-spacing`, `--weights l:n,...`. Adds `bg,wm,cor,cer` silently if only cortical labels given.
- **`exp test visualize TEST_FILES...`** C:1389 → EX:782. Plot test sample centres on background (`--background-pattern`, `--output-pattern`, `--spacing 64`).
- **`exp vis area CONFIG`** C:1445 → EX:841. Draw sampling areas / `--probability` maps of `--split train`. Broken on shapely 2 (descartes) and matplotlib ≥3.9 (`cm.get_cmap`).
- **`exp vis labels BRAIN SLICE LABELS...`** C:1525 → EX:998. Show ground truth from constants paths; `--output`, `--spacing`.
- **`exp vis pmaps CONFIG`** C:1546 → EX:1048. Interactive sampler probability maps (`--split`, `--sampler-mode`); needs a DistributionSampler.
- **`exp compare FILES...`** C:1570 → EX:1090. Side-by-side: images in a grid; JSON pretty/`--key K` table, `--plot` bar chart; text otherwise. `--image-output`, `--cmap gray|labels`, `--figure-size`, `--y-limits`. Image mode broken on matplotlib ≥3.9.
- **`exp samples create CONFIG OUTPUT_FILE NUM`** C:1695 → EX:1353. Draw NUM samples from the config's sampler (`--split train`, `--seed 1337`) → JSON for a `file` sampler (includes config text, seed, version).
- **`exp tensorboard DIRS... [--port 6006]`** C:1729 → EX:1437. Symlink runs into a temp logdir named by experiment, launch `tensorboard`.
- **`exp batch CONFIG_JSON TEMPLATES...`** C:1752 → EX:1492. Stamp out experiment folders in CWD from templates: cross product of list values; top-level list = separate configs; `__EXPERIMENT_NAME__`/`__EXPERIMENT_PATH__` substituted. `--prefix`, `--experiment-format`. Does not submit jobs.

## img
All write HDF5 pyramids (`pyramid/00..`) unless noted. MPI-parallel over files/sections unless noted.
- **`img ann2hdf5 JSONS... IMAGE_PATTERN OUTPUT_PATTERN`** C:1810 → IM:105. MicroDraw annotation JSON → label raster + `labels`/`colors` attrs + PNG preview. `--input-spacing 1`, `--output-spacing 16`, `--prefix mask`, `--labels a,b`, `--config JSON` (alias/regex renames, per-section `rotation`), `--chunk-size`, `--compression`, `--overwrite`. OUTPUT_PATTERN must contain `B##`. IMAGE_PATTERN may be a JSON with height/width/spacing.
- **`img tif2hdf5 IN_DIR OUT_DIR`** C:1913 → IM:346. Every `*.tif[f]` → `<stem>.hdf5` uint8 gray pyramid. `--sections`, `--num-levels 8`, `--downscaling-factor .5`, `--scales`, `--output-spacing`, `--chunk-size`, `--compression`, `--overwrite`. Per-file errors only logged at INFO. Memory-heavy.
- **`img hdf5merge INPUT_PATTERN OUTPUT_FILE`** C:2015 → IM:508. Merge per-section files into one file with groups `/####` (`--sections`, `--driver`). Serial.
- **`img png2mask PNGS... IN_SPACING OUT_PATTERN OUT_PREFIX LABEL_VALUES`** C:2040 → IM:547. Colour PNG → label mask. LABEL_VALUES = `;`-separated Python literals, `eval`'d: `"(0,0,0,255);(83,83,83,255)"`.
- **`img png2hdf5 PNGS... OUT_PATTERN IN_SPACING`** C:2097 → IM:1683. RGB→gray pyramid. `--interpolation` default 3 (use 0 for labels), `--num-levels`, `--prefix`.
- **`img extract IMAGES... OUT_PATTERN SPACING`** C:2179 → IM:661. Export TIFF at a spacing. Always skips existing.
- **`img link MICRODRAW_CONFIG IN_DIR OUT_PATTERN`** C:2220 → IM:710. Symlink scans named `B##_####_TS##_Pyramid.tif` (hard-coded regex) listed in a MicroDraw config. Use absolute IN_DIR.
- **`img threshold IMAGES... OUT_PATTERN`** C:2254 → IM:781. Tissue/binary mask: `--threshold-method otsu|<int>`, `--threshold-mode greater|less`, `--spacing 64`, `--median-filter-size 3`, `--small-objects-size`, `--small-holes-size`, `--mask-dilation/--mask-erosion`, `--clahe-size`, `--output-label`, `--masks` (restrict to other masks), `--overwrite`.
- **`img mask2contours MASKS... OUT_PATTERN`** C:2395 → IM:1023. Mask → MicroDraw JSON polygons (`<label>_<k>`). Pass `--interpolation 0` for label masks (default 3).
- **`img show-contours JSONS... REFERENCE_PATTERN`** C:2460 → IM:1101. Draw contours over a reference image (`--output-pattern`, `--alpha`). Broken on shapely 2.
- **`img show IMAGES...`** C:2557 → IM:1209. Interactive viewer (arrow keys), `--layout R C`, `--spacing 64`, `--bbox`, `--labels`, `--one-hot`, `--vmin/--vmax`, `--cbar`, `--output PATTERN` (save PNGs instead).
- **`img info IMAGES... [--prefix] [--json]`** C:2684 → IM:1360. Prefix, labels, spacing(s), chunk size, shape, pyramid shapes. Fast, safe: first thing to run on an unknown image file.
- **`img overlay BG FG`** C:2713 → IM:1397. Overlay two images (`--alpha .5`, `--{prefix,interpolation,color-map,labels,input-spacing}-{bg,fg}`, `--use-pattern` to pair sections, `--align-size`, `--output`). Leaks memory on long `--use-pattern` runs.
- **`img png IMAGES...`** C:2864 → IM:1603. Quick PNG next to each input or `--output-dir` (`--spacing 64`, `--color-map`, `--labels`, `--overwrite`).
- **`img mask2laplace MASKS... OUT_PATTERN PREFIX INNER_VALUES OUTER_VALUES`** C:2989 → IM:1762. Laplace field between inner/outer label sets (cortical depth); `--spacing 64`, `--sigma 3`, `--max-iterations 5000`, `--max-error 1e-5`, `--save-gradients` (dx, dy). No overwrite check.
- **`img transform IMAGE TRANSFORMATION OUTPUT`** C:3097 → IM:1880. Apply a registration transform. `.tif` out → pyramidal BigTIFF, else HDF5. `--spacing 64`, `--interpolation 0`, `--reference-image`, `--invert`, `--dtype`, `--fill`, `--use-pattern` (last 4-digit number → `*`).

## reg
- **`reg convert IMAGES... OUT_PATTERN IN_SPACING OUT_SPACING`** C:3225 → RG:9. Gray + median + Otsu tissue mask → NIfTI + `_mask.nii` (elastix input). Uses removed skimage `selem=` → may fail on new skimage.
- **`reg apply JSONS... ANN_SPACING TRANSFORMATION_PATTERN OUT_FOLDER`** C:3256 → RG:108. Apply elastix/JSON transforms to MicroDraw annotations.
- **`reg verify FIXED_PATTERN MOVING_PATTERN FIXED_FOLDER MOVING_FOLDER`** C:3295 → RG:156. Symlink sections present in both into two folders (no image check despite docs).
- **`reg brain2pm BRAIN`** / **`reg pm2brain PM_CODE`** C:3322/C:3333. Brain id ↔ postmortem code (no trailing newline).
- **`reg feature-based FIXED_PATTERN MOVING_PATTERN OUT_PATTERN`** C:3344 → RG:257. SIFT+FLANN+RANSAC per section → JSON transform. `--transformation-type affine|rigid`, `--registration-spacing 64`, `--section-range A B`, `--exclude-sections`, `--matches-output-pattern`, `--overlay-pattern` (QC overlay), `--overwrite`. Globs every file in the pattern's dir.
- **`reg consecutive IMAGES... OUT_PATTERN`** C:3423 → RG:383. Register each section onto the previous one (same options).

## data
- **`data batch show BATCH_FILES...`** C:3500 → DA:11. View/save batches written by `Batch.to_hdf5`. `--data-sources a,b`, `--output DIR` (must exist), `--to-png` (crashes without `--output`).
- **`data batch generate CONFIG_FILE OUT_DIR SPLIT`** C:3554 → DA:167. Dump real batches from a config to check the data pipeline: `--batches 100`, `--batch-size`, `--no-transformation`, `--fake-data`. Writes `batch_####_split_<split>.hdf5`. CONFIG must be the file, not a folder.
- **`data brainlink PATTERN FILES... [--copy|--rename]`** C:3641 → DA:301. Link/copy/move files into a brain/section naming pattern. Relative inputs → broken links.
- **`data section-check PATTERNS... [--diff] [--print-existing] [--section-range A B]`** C:3685 → DA:377. Which sections are missing per pattern; `--diff` table across ≥2 patterns.
- **`data section-json GLOBS...`** C:3724 → DA:482. JSON of `[brain, section]` pairs (`--group-by-brain`).
- **`data hdf5 link FILES... SRC DST`** C:3762 → DA:513. In-place hard link `f[DST]=f[SRC]`.
- **`data hdf5 attr FILES... PREFIX KEY VALUE`** C:3789 → DA:558. Set attribute; VALUE is `eval`'d (strings need inner quotes `"'abc'"`).
- **`data hdf5 attr-copy FILES... SRC_PREFIX DST_PREFIX [--overwrite]`** C:3812 → DA:616.
- **`data hdf5 colors FILES... PREFIX NUM [--seed 1337]`** C:3846 → DA:665. Random label colours (first = black).
- **`data stage-zarr [PATHS...] [-L FILE] [-d /dev/shm]`** C:3874 → DA:716. Copy Zarr stores to RAM; run once per node (`srun --ntasks-per-node=1`). `-p` rsync include patterns, `-o` overwrite.

## shell
For `$(...)` in bash; no trailing newline.
- **`shell brain STRING [--to-int]`** C:3938 → `B##` or int. **`shell section STRING [--format]`** C:3958 → section (4-digit with `--format`). **`shell format TEMPLATE --brain B --section N`** C:3973 → filled template.

## Gotchas
- Broken: `dl simulate`; `dl predict --cache-mode memory`; `data batch show --to-png` without `--output`.
- Old-library breakage: shapely 2 (`exp vis area`, `img show-contours`), matplotlib ≥3.9 (`exp vis area`, `exp compare` images), skimage `selem` (`reg convert`).
- `eval` on input: `img png2mask` LABEL_VALUES, `data hdf5 attr` VALUE.
- Destroys data without prompt: `exp run clean`, `exp run compress` (no `--keep`), `exp model reduce --delete`, `dl predict-points` (overwrites output), `data brainlink --rename`, `data hdf5 *` (in place).
- Depend on `.atlas.json`/`ATLAS_*` constants: `exp test create|visualize`, `exp vis area|labels`, `img ann2hdf5` default prefix.
