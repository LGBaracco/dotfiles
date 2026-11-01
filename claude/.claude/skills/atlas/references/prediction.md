# atlas prediction, feature extraction, evaluation

Paths relative to `$ATLAS_SRC/atlas/` (atlas `v0.3.0-6-gc64050cf`); `dl.py` = `cli/dl.py`. Job script: `../templates/predict_points.sbatch`.
Before computing: check whether the outputs already exist (`<run>/results/predictions/...`, other people's runs).

## Which command
| want | command |
|---|---|
| features / class scores for a list of points (patch-level) | `atlas dl predict-points EXP POINTS.hdf5...` |
| dense map over whole sections (segmentation / tiled) | `atlas dl predict EXP` (config's **val** split, grid sampler) → `atlas dl evaluate` |
| dense map with an explicit model + output pattern, no experiment | `atlas dl segment WORKDIR MODEL.pt OUT_PATTERN` |
| metrics for point predictions with labels | `atlas dl evaluate-points FILES... f1,iou out.h5` |

## Reuse a trained model for prediction (no config writing)
```bash
atlas exp new my_features                                   # YYYY_MM_DD_my_features/
atlas exp run copy <src_exp>/YYYY_MM_DD_runNN --dst YYYY_MM_DD_my_features   # config + models symlink (--copy-models to copy)
atlas exp model active <run>/models/training_state_NNNN.pt  # only if active_model isn't that checkpoint
```
`--dst` must exist; the new run must be writable (logs). `exp model active` writes the link next to the **resolved** file (symlinked `models/` → needs write access there, else `--copy-models`).

## `dl predict-points` (C:681 → `dl.py:1372`)
**Inputs** (HDF5 only; JSON fails): brain3d AnchorPoints (`vertices_per_section_2d`, attr `brain`, optional `features["labels"]` carried over) or an HDF5 sample file (`boxes/0/center`, `dl.py:1472`; extra columns like `ras`, `label` copied to the output). Each point → `Sample(center, brain, slice_no, spacing=1)`.
**Config changes it makes**: uses `--split` (default **train**) iterator params, replaces the sampler with a `lambda` sampler over the points, disables augmentation (unless `--enable-transformations`), overrides batch size, builds output sources only with `--include-output`.
**Model**: `make_network(...)` (num_classes placeholder 42 if unset) + weights from `files.get_latest_training_state(run)` (`active_model` else highest `.pt`), `strict=--strict-weights` (default False: missing/unexpected keys only logged → check the log). No `--model` option.
**Inputs → samples**: AnchorPoints points get `spacing=1` (pixel coordinates at 1 µm); sample-file rows keep their own `spacing` column. Output rows = input rows grouped by section, file order within a section (`--subsample-points k` keeps every k-th).
**What is computed** (`dl.py:1766-1791`), one of:
- default: `{"features": model(x)}`.
- `--output-configuration name:attr[,name2:attr2]` — ONE comma-separated value (repeating the flag doesn't add outputs). `attr=""` whole model; `attr="encoder"` calls that submodule directly on the input; `attr="@hook:module.path"` forward hook while running the full model (for submodules needing context, e.g. `@hook:output`, `@hook:encoder.body.vit`). Paths are dotted from the model root as in `model.named_modules()` (build the model as in python-api.md and print `[n for n, _ in model.named_modules()]` if unsure).
- `--output-adapter FILE[:FACTORY]` (factory default `make_adapter`): `factory(model)` → callable returning a Tensor or `{name: Tensor}` (batch dim = #samples). `nn.Module` adapters are moved to device + eval. Contract tested in `tests/test_output_adapter.py`.
**Other options**: `--name SUBDIR`, `--output-dir`, `--batch-size`, `--amp`, `--max-points N` (per file; quick smoke tests — unprocessed rows come out as zeros), `--subsample-points k`, `--sample-attr k:v` (adds string attrs for SampleFilter sources), `--include-input`, `--stochastic-forward-passes T` + `--stochastic-forward-seed` (MC dropout, output `(B,T,...)`), `--fake-data`, `--verbose`.
**Parallelism**: under `srun` points are spread over ranks automatically (no `--distribute`); needs ≥2 ranks per GPU. Single process = sequential; on a login node CPU works for tiny tests: `--max-points 1 --batch-size 1`, no `--amp`, no `srun`.
**Output**: `<--output-dir or run/results/predictions>[/<--name>]/<basename(input)>` — existing file deleted and rewritten; two inputs with the same basename collide. Temp `tmp_point_prediction_<rank>_<basename>` (sparse `features/<name>/<section>/{indices,values}`) merged per section (`_combine_point_prediction_files` `dl.py:2225`). Final layout = AnchorPoints: group `%06d` per section with `2d` (+`3d`) and one dataset per feature; input features copied; attrs `run_dir`, `model`, `config`, `input_file`, `sample_attr_<k>`, `subsample_points`.
Typical:
```bash
srun --cpus-per-task 4 atlas dl predict-points <exp> points.hdf5 \
     --output-configuration backbone:encoder --amp --batch-size 64 --name frozen
```

## Reading predict-points output (container Python / atlas Jupyter kernel)
```python
from brain3d.data import AnchorPoints
ap = AnchorPoints.load(fname, lazy=True, include_features=["backbone"])
X, sections = AnchorPoints.data_per_section_to_array(ap.features["backbone"], return_sections=True)
df = ap.to_pandas()   # one row per point: sections, 2d_x/y, 3d_*, <feature>_0..D-1, copied columns (brain, labels, ...)
```
Plain h5py works too: `f["%06d" % section]["backbone"]`. Quick looks without code: `b3 analyze pca|umap`, `b3 vis anchor2d` (companions.md).

## `dl predict` (C:211 → `dl.py:497`) — dense / tiled
- Config needs a **val** split: typically `sampler_mode="grid"`, `grid_sampler_output_format=OutputFormat(out_size, out_spacing)`, `AreaProviderParams(area_mode="whole"|"mask", slices=[(brain, section)...])`; `--slices` overrides.
- Model: `--model FILE`, else `models/active_model` (set it with `exp model active`; torch runs have no `model_NNNN.hdf5` fallback).
- Writes `<run>/results/predictions/` file per section, name `params.prediction_filename_pattern` or `B{brain:02d}_{slice:04d}_{spacing:02d}.hdf5` (spacing must be int). Dataset `<output_ds>_<area_id>` (e.g. `segmentation_whole`): float32 `(H,W,C)` softmax (softmax only in segmentation modes) or, with `--save-argmax`, `(H,W)` int; attrs `bbox`, `spacing`, `labels`; `_mask_<prefix>` when the area has a mask. Overlapping tiles: first non-background prediction wins (no averaging). Nearest-neighbour rescaling to `--output-spacing`.
- Only the first model output is used; only Label/Image output sources are written. `prediction_cropping_size` centre-crops outputs.
- Existing sections are skipped unless `--overwrite` (skip logic `prediction/prediction.py:666` looks buggy; use `--overwrite` when in doubt).
- Python: `atlas.prediction.make_predictor(model_path, params, output_spacing, results_folder, iteration, ...)` → `.predict()` (`prediction/__init__.py:7`); needs `parallel.setup_master_slave_communication()` when run in parallel.

## `dl evaluate` (C:344 → `dl.py:746`)
Reads `results/predictions`, writes only what you ask for: `--write-report` (accuracy/IoU/precision/recall/F1 per label, PDE, confusion matrix → `results/reports/metrics_report_iteration_NNNN[_split_X].{txt,json}`), `--write-confusion-matrix`, `--write-overview`, `--write-training-statistics`, `--pred-to-png`, `--pred-to-hdf5`, `--embedded-pred-*`, activations. Ground truth from constants paths (`annotation`, `bg_cor_wm_segmentation`). Serial; run without `srun`.
Read reports in Python: `atlas.experiments.Run(path).read_report(iteration=None, split=None, json=True)` / `.get_key_from_report(key)`; rank runs: `RunCollection("exp/*/active_run").create_ranking_table("f1")` (python-api.md).

## `dl evaluate-points` (C:514 → `dl.py:876`)
`atlas dl evaluate-points files*.hdf5 accuracy,f1 metrics.h5 [--labels-file labels.json] [--prediction-key classes] [--labels-key labels] [--experiment-name X]` → per-label values (no averaging) in `pd.read_hdf("metrics.h5", "metrics")`. Python: `atlas.evaluation.points.metrics.compute_metric_for_anchor_points(fnames, "f1", average="macro"|"micro"|"none")`, `get_cm_from_anchor_points`, `compute_metrics_per_brain_from_anchor_points(..., return_df=True)`, `plot_cm`. Requires integer label indices + identical label lists across files. Label names are read from root attr `labels` (`samplestuff ann2anchor` writes `label`, singular → rename the attr or pass `--labels-file`). With galaxy's datalad: `galaxy/scripts/compute_metrics_test_transfer.sh` shows the pattern.

## Activations / embeddings
`dl predict --write-activations --activation-layers a,b` → `results/activations/`; `dl evaluate --write-embedded-activations` / `--write-image-activations`. `atlas.evaluation.evaluation.Activation`, `ActivationEvaluator` (`evaluation/evaluation.py:1902,2070`).
