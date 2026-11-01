# atlas as a Python library

Paths relative to `$ATLAS_SRC/atlas/` (atlas `v0.3.0-6-gc64050cf`). Run inside the galaxy container (`python`/`ipython`/Jupyter kernel `atlas`) or an env with atlas installed (`pip install -e .`; jugit deps need credentials).

## Import facts
- `import atlas` needs an installed package (`importlib.metadata.version`).
- Importing `atlas.experiments` or `atlas.data.image_provider` (also the CLI) creates `/dev/shm/atlaslib-zarrjson-cache/<host>[/$SLURM_JOB_ID]` and tries `import hdf5plugin`. Import atlas **before** `mpi4py.MPI` (`configure_mpi` raises otherwise).
- Samplers, BatchIterator, Predictor, logger import `atlas.experiments.parallel` → MPI init (atlasmpi or mpi4py stub). Single process (Jupyter) is fine.

## Experiments, runs, models (`experiments/`)
- `atlas.experiments.Experiment(path)` (`experiments_oo.py:64`): `.runs`, `.active_run` (Run; FileNotFoundError without `active_run` link), `.config_path`, `.load_config()`.
- `Run(path)` (`:108`): `log_dir`, `results_dir`, `reports_dir`, `plots_dir`, `models_dir`, `config_path`, `diagnostics_files`, `overview_image_files`; `.load_config()`, `.read_report(iteration=None, split=None, json=False)` (`:227`), `.get_key_from_report(key)` (`:257`), `.read_overview_image`, `.make_overview_image_video`. `.load_model` is BROKEN.
- `RunCollection("exp/*/active_run")` (`:357`): `.create_ranking(key, split, order)`, `.create_ranking_table(...)`, `.plot_ranking(...)`.
- Load a model yourself (what `torch/prediction.py:151` does):
  ```python
  import torch
  from atlas.experiments import load_config, files
  from atlas.configuration import config
  from atlas.configuration.data_source import get_input_shapes, get_data_sources_by_input_output_mapping
  p = load_config(run_dir).make_training_parameters()     # experiments.py:19, imports <run>/config.py
  srcs, _ = get_data_sources_by_input_output_mapping(data_sources=p.iterator_params[config.TRAIN_SPLIT].data_sources,
                                                     input_output_mapping=p.input_output_mapping)
  shapes, _ = get_input_shapes(input_data_sources=srcs)
  model = p.network_params.make_network(input_shape=shapes, input_spacing=[s.spacing for s in srcs], num_classes=p.num_classes)
  path = files.get_latest_training_state(run_dir)          # files.py:417 (active_model else highest .pt)
  model.load_state_dict(torch.load(path, map_location="cpu")["model"]); model.eval()
  ```
- `files.py`: `get_latest_run_dir(root)` (`:473`), `is_run_folder` (`:540`), `get_run_directory_from_path` (`:564`), `create_run_folder` (`:12`, UTC date), `set_active_run` (`:41`), `set_active_model` (`:64`), `get_latest_model` (`:392`), `get_by_pattern(root, regex)` (`:444`; returns `[]` on no match), path getters `get_{config,models,logs,diagnostics,results}_path_of_run`. `get_checkpoints_of_run` recurses forever (`:263`) — don't call.
- `experiments.py`: `setup_config(src, dst)` (`:86`, fills `"$MEAN_<CH>"` etc.), `calculate_mean_std` (`:325`), `count_labels` (`:289`), `get_mean_std_for_run(run, channel)` (`:374`), `get_elements_for_process(elems, rank, size, mode)` (`:769`), `init_logging(verbose, quiet)` (`:531`), `get_logger()` (`:628`), `Timer()` (`:819`; `with t:` then `t.elapsed_time` — `with Timer() as t` gives None).
- `diagnostics.py`: global `events`; `add/append/get/reset/save(directory, mode)` (`:215-299`). `memory.py:24 NodeMemoryUsage().get_report("GB")`. `profiling.py:13 start_profiling(output_folder, module="cprofile"|"mtprof")`.

## Reading images and labels
- `ImageProvider(ImageProviderParams(...), keep_files_open=True, seed=None)` (`data/image_provider.py:597`) or `.create_from_default_params()` (`:689`, uses `.atlas.json` paths).
  `get_data(image_specification, bbox=None, wanted_spacing=None, wanted_channels=None, tform=True, ...)` (`:744`) → `ImageData` (dict-like `data[channel]`, `.attrs[channel]`, `.bbox`). `bbox=None` = whole image. `tform=False` = no augmentation.
  `read_labels(bbox, wanted_spacing, labels, image_specification, default_label="bg")` (`:1422`) merges annotations + bg/cor/wm segmentation. Also `check_exists`, `get_image_shape(spec, channel, spacing)` (`:1407`), `get_image_handle`.
- `ImageSpecification(brain=1, slice=1234, ...)` (`:379`): hashable key; any `{key}` from filename patterns becomes a field.
- Low level (atlaslib): `Image.get_image(path, prefix="1234")`, `img.get_crop(bbox=BoundingBox(center=(x,y), w=2048, h=2048, spacing=2), spacing=2)`; `atlaslib.neuro.pm_to_brain_id("pm54491") -> 1`.
- `image/io.py`: `identify_image(path)` (`:15` → prefix, labels, spacing, shape, pyramid shapes), `show_image(path, spacing=64, ...)` (`:135`), `GroundtruthReader(annotation_pattern, bg_cor_wm_pattern, prefixes).get_crop(brain, section, spacing, labels, bbox)` (`:372`), `HistologyReader`, `TissueReader`, `ProbabilityMapReader` (`:517-539`, constants paths).

## Building batches from Python (debug data pipeline / custom loops)
Pattern from `tests/test_sample_filter_data_source.py`:
```python
from atlas.configuration import config, data_source as ds
from atlas.data.batch_iterator import BatchIterator
from atlas.data.sampler import Sample
it = BatchIterator(config.IteratorParams(batch_size=4, data_sources=[ds.ImageDataSource("x", config.CHANNEL_HISTOLOGY, spacing=2, size=256)],
                   sampler_params=config.SamplerParams(sampler_mode="lambda", lambda_sampler_generator=lambda: iter(()))))
batch = next(it.generate_batch(samples=[Sample(center=(x, y), spacing=1, brain=1, slice_no=1234)]))
arr = batch.find_data_by_name("x")      # Batch API: data/batch_iterator.py:47 (.samples, .to_hdf5, get_data_by_input_output_mapping)
```
`it.enable_fake_data()` for shape-only tests. Distributed variants (`BlockingDistributedBatchIterator` etc., `:1967-2763`) are wired by the trainers.

## Samplers in Python
`data/sampler.py`: `create_sampler(SamplerParams)` (`:221`) → `.sample()` generator. `GridSampler` yields finite tiles; `Hdf5NearestNeighborSampler` (`:867`) KDTree over a column; `ProbabilityDistribution` (`:1803`) `.visualize_probabilities()`, `.to_hdf5()`. Area records: `data/area_provider.py` `AreaRecord` (`:85`), `GenericAreaProvider(params, areas)` (`:1119`, Python-only custom areas).

## Evaluation helpers
- `evaluation/metrics.py` (cm rows = true): `confusion_matrix(y_pred, y_true, normalize)` (`:246`, **pred first**), `accuracy|precision|recall|f1|iou_from_cm` (`:59-151`), `iou_per_label`, `mean_iou`, `create_report` (sklearn) (`:402`), `pretty_confusion_matrix`.
- `evaluation/points/metrics.py` (AnchorPoints): `get_cm_from_anchor_points(fname, labels, normalize)` (`:46`), `get_combined_cm_from_anchor_points` (`:74`), `compute_metric_for_anchor_points(fnames, metric, average)` (`:234`), `compute_metrics_per_brain_from_anchor_points(..., return_df)` (`:275`), `plot_cm`, `plot_cm_difference`. `find_anchor_points_for_run(..., open=True)` broken → `open=False`.
- `evaluation/visualization.py`: `plot_confusion_matrix(cm, labels)` (`:111`), `create_loss_plot`, `create_accuracy_plot`.
- `evaluation/distances.py`: `calculate_distance_to_mask` (`:6`), `calculate_distances_to_labels` (`:33`).

## Image processing
- `image/laplace.py`: `calculate_laplace_field(outer_mask, inner_mask, sigma, kernel_size)` (`:7`; cortical depth 0→1), `calculate_laplace_gradients` (`:77`), `extract_level_contours(field, level)` (`:105`), `integrate_point_in_gradient_field` (`:156`, streamlines). CLI `img mask2laplace`.
- `image/registration.py`: `register(fixed, moving, output_json, spacing_fixed, spacing_moving, flann_matcher, transformation_type="affine"|"rigid", ...)` (`:131`; SIFT+FLANN+RANSAC), `create_flann_matcher()` (`:47`).
- `image/video.py`: `make_video_from_image_files(files, out, fps=5)` (`:7`), `display_video_in_notebook`. `image/util.py`: `apply_color_map` (`:6`).
- `util/polygon.py`: `mask_to_polygons(mask, bbox, mask_spacing, output_spacing)` (`:6`), `polygons_to_mask(polys, input_spacing, output_spacing, clip_bbox)` (`:73`), `bbox_to_polygon`, `get_union_of_polygons`, `resample_polygon(coords, n)` (`:312`). `util/curves.py`: `fit_spline`, `resample_curve(coords, n, "cubic")` (`:45`).

## Labels and colours
- `labels.py`: `format_label_array(label_arr, from_labels, to_labels, default_label="bg", bg_cor_wm_segmentation, ...)` (`:99`; file labels → training indices), `normalize_labels`, `decompose_label_list` (`"V1+V2"`), `get_equivalent_labels` (`hOc1`=V1, `:26`), `read_groundtruth(annotation_path, bg_cor_wm_path, wanted_spacing, labels, bbox)` (`:466`), `calculate_mask_for_cortex` (`:424`), `find_label_borders` (`:281`).
- `neuro/mapping.py`: `BG/COR/WM/CER_LABEL`, `AUXILIARY_LABELS`, `label_color_dict(labels)` (`:251`), `label_color_map(labels, normalize)` (`:279`), `parse_cortical_area_name` (`:176`).

## Tests (`$ATLAS_SRC/tests/`)
`pytest` (needs atlaslib, brain3d, typhon, torch). Useful as executable docs: `test_sample_filter_data_source.py` (BatchIterator from Python), `test_hdf5_nearest_neighbor_sampler.py` (minimal HDF5 sample file), `test_output_adapter.py`, `test_predict_points_combine.py`, `test_model_gitignore.py` (CLI via `CliRunner`). Distributed loss checks: `cd tests/distributed && bash run_loss_equiv_local.sh` (relative paths; `run_loss_equiv_mpi.sh` under srun).
