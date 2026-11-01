# Companion packages in the galaxy container

Source = dev checkouts `$GALAXY_ROOT/code/<pkg>/` (read via the sshfs mount, `../local-setup.md`); `file:line` relative to that package dir. HEADs checked 2026-11-01.
Commands exist after `module load atlas`; Python packages are importable in container `python`/Jupyter kernel `atlas`.

| package | HEAD | CLI | purpose |
|---|---|---|---|
| brain3d | de40e9a5 2026-07-09 | `b3` | AnchorPoints HDF5 format, section stacks → volumes → cortical meshes → per-section points |
| samplestuff | 14273eb 2026-09-02 | `samplestuff` | move values between volumes, meshes, AnchorPoints, masks, annotation DBs (nearest neighbour) |
| annotation_db | 06bba25c 2026-04-15 | `anndb` | folder/JSON database of area polygons (MicroDraw, SectionTracer/OST) |
| colin | 6b6aef7 2026-05-20 | `colin` | Colin27 MRI space ↔ 20 µm histological sections |
| tseg | 8be6e00 2025-07-25 | `tseg` | classical bg/cortex/wm tissue segmentation |
| atlas3d | 7ad271f 2025-07-25 | `atlas3d` | mesh graphs + GNN prediction on top of atlas (stale) |
| atlaslib | 7c194dd 2026-08-28 | — | image I/O + pyramids, BoundingBox, filename patterns, click types, transforms, ComBat |
| typhon | a89088a 2025-04-15 | — | MPI work distribution, shared memory, chunked algorithms |
| atlasmpi | 5aa7c9a 2026-09-23 | — | `from atlasmpi import MPI`: real mpi4py under srun/mpirun, single-rank stub otherwise |
| dms | 569a280 2026-04-02 | — | dead man's switch (kills/scancels hung jobs) |
| rambo | ee0834f 2025-05-21 | — | stage files to `/dev/shm` |

Units everywhere: spacing = µm/px; AnchorPoints `2d` = µm (x = column), `3d` = mm RAS of the reconstructed volume.

## brain3d (`b3`)
### AnchorPoints (`brain3d/data.py:14`) — the per-point file format of predict-points, ann2anchor, b3
- HDF5: one group per section `"{section:06d}"` (attr `section`) with `2d` (N,2), `3d` (N,3), one dataset per feature (`features`, `labels` (bytes), `ras`, `tissue_histogram`, `pmap`, `mpm`, `2d_raw`, `pca`, `umap`, ...); same N in every dataset of a section. Root attrs e.g. `brain`, `side`, `mesh_file`, `center_section`, `affine_matrix`, `refinement_*`, `labels`/`label` (label names), `kdtree` (only with `include_kdtree`). `link_features=True` writes features to side files `<base>.feature_<name>.hdf5` (move them together).
- `AnchorPoints.load(fname, lazy=False, include_features=None, exclude_features=None, slice_per_feature=None)` (`:192`). `lazy=True` keeps the file open (h5py datasets). `2d`/`3d` always loaded. Bugs: include+exclude together drops `2d`/`3d`; lazy + byte-string features breaks → load string features non-lazily.
- Object: `vertices_per_section_2d`, `vertices_per_section_3d` (dict section → array), `features` (`{name: {section: array}}`), `attrs`.
- `save(fname, overwrite=False, include_features, exclude_features, link_features, no_points_2d, no_points_3d, include_kdtree)` (`:261`).
- `to_pandas(include_features, exclude_features, inf_to_nan=True)` (`:544`): columns `sections, 2d_x, 2d_y, 3d_x, 3d_y, 3d_z, <feat>` or `<feat>_<i>`, `brain`. `from_pandas` is BROKEN.
- `data_per_section_to_array(d, return_sections=False, padding_reference=None)` (`:371`, static; sorted section order, NaN-pads missing sections) and `array_to_data_per_section(array, d)` (`:420`): consistent only for sorted dicts (true for loaded files).
- `filter(mask, remove_empty=True)` (`:431`, IN PLACE; flat bool mask or dict section → mask), `copy()` (`:167`), `add_feature(key, data)` (`:180`), `from_files(files, lazy)` (`:28`, per-section concat; conflicting attrs → `conflicting_attributes`), `join(files, join_properties=[{k: v}])` (`:132`, adds a constant feature per file), `split(split_properties)` (`:144`), `build_kdtree_3d()` (`:358`), `get_features_per_vertex(key, vertices)` (`:493`), `sample_features_from_data(key, data_by_section, data_spacing)` (`:475`), `to_mesh(fname)` (`:590`).
- Module: `sample_points(points, data, points_spacing, data_spacing)` (`:607`), `sample_by_anchor_points(...)` (`:646`).
- PyTorch: `brain3d.torch.AnchorPointsFeatureDataset(files, feature="features")` (`torch.py:29`, lazy streaming, `(row, global_index)`, `split_array_per_file`).

### `b3` commands (`brain3d/cli.py`)
- `b3 vis anchor2d ANCHOR IMAGE` (`:27`): points of IMAGE's section over the image; `--feature`, `--feature-cmap plasma`, `--feature-dim`, `--spacing 64`, `--labels`, `--output` (else show).
- `b3 process resample REFERENCE TARGET OUTPUT {2d|3d}` (`:126`): copy features from nearest reference points (`--overwrite-features`, `--remove-missing-sections`).
- `b3 process concat INPUTS... OUTPUT` (`:203`): per-section concat; attrs from the first file.
- `b3 process filter IN OUT --include-section-filter SLICES --exclude-section-filter SLICES` (`:251`).
- `b3 process link INPUTS... SRC DST` (`:294`): in-place alias of a feature.
- `b3 process subsample IN RATE OUT` (`:324`): `--subsample-mode linear|random`, `--subsample-seed 0`, `--include-features`, `--exclude-features`.
- `b3 convert samples2anchor IN OUTPUT_PATTERN` (`:365`): atlas HDF5 sample file → one AnchorPoints file per brain (`--samples-key boxes`, `--brains`, `--labels-key labels`, `--include-features a,b`); points stored as `center*spacing` µm.
- `b3 convert anchor2samples INPUTS... OUT` (`:433`): → atlas sample file (`--features-to-include`); bug: `label` gets the whole dict.
- `b3 convert anchor2mesh INPUTS... OUT` (`:488`): point cloud (`--input-feature`, `--point-feature`).
- `b3 analyze pca IN FEATURE SCALER.pck PCA.pck OUT` (`:546`): StandardScaler + PCA, pickled (`--output-key pca`).
- `b3 analyze umap IN FEATURE UMAP.pck COMPONENTS OUT` (`:599`): `--neighbors 15`, `--metric`, `--seed`, `--output-key umap` (needs umap-learn).

### brain3d API beyond AnchorPoints
- `mesh.py`: `graph_cut_mesh` (`:58`, hemisphere split), `extract_mesh_by_vertex_mask`, `largest_connected_component_mask`, `vertices_in_mask_volume`, `vertices_ras_to_ria`/`ria_to_ras`, `cut_mesh_by_plane`, `extract_section_contour_from_mesh`, `transform_3d_to_2d` (`:531`), `transform_sections_from_3d_to_2d` (`:570`), `transform_sections_from_2d_to_3d` (`:749`), `color_mesh_by_anchor_points` (`:829`), `smooth_features_on_mesh` (`:852`).
- `transform.RecursiveTransformation(pattern=None)` (`:24`, reads `.atlas.json` transformation paths if None); `volume.volume_from_stack`, `write_nifti`; `normalization.stain_norm_beta`; `tissue.filter_anchor_points_by_tissue_share`. `masks.py` uses `np.bool` (numpy ≥1.24 breaks).

### `brain3d/scripts/` (click; `README.md` = pipeline steps 1–9)
- Add features to AnchorPoints: `add_areas_to_anchor_points.py IN OUT ANNOTATION_DB [--include-file]` (→ `labels`, `labels_color`), `add_ras_to_anchor_points.py IN OUT RAS_PATTERN [--prefix /ras/pyramid/00 --spacing 211.667 --output-key ras]`, `add_pmaps_to_anchor_points.py IN OUT PMAP_FILE` (→ `pmap`, `mpm`), `add_cutting_angles_to_anchor_points.py IN OUT PATTERN`, `add_histograms_to_anchor_points.py IN OUT` (MPI), `tissue_histogram.py TISSUE_MASK_PATTERN ANCHORS... OUT_PATTERN` (MPI), `warp_ras_to_mni152.py IN OUT [--input-space colin27 --output-space mni152]` (siibra).
- Points from meshes/grids: `compute_anchor_points_from_mesh.py MESH REF_VOLUME OUT` (needs `<REF_VOLUME>.info.json`), `compute_anchor_points_from_mesh_B20.py` (BigBrain), `create_whole_brain_anchor_points.py IMAGE_PATTERN MASK_PATH [--grid-spacing-mm 5]` (regular 2D grid), `refine_points_by_laplace.py MASK_PATTERN ANCHORS... OUT_PATTERN` (moves points to the cortical midline; MPI, must run under srun; bug: `2d_raw` ends up holding refined points; `.sh` = sbatch template).
- Volumes/meshes: `sections_to_3d.py`, `extract_surface.py`, `clean_cortex_mesh.py`, `split_hemispheres_graphcut.py`, `remesh_surface.py`, `compute_poisson_reconstruction.py`, `sulcal_depth.py`, `color_mesh_by_*.py`, `compute_cutting_angles.py`, `normalization.py`, `downscale_volume.py`, `mask_volume.py`; shell pipelines `mesh_pipeline.sh`, `masks_to_3d.sh`, `histology_to_3d.sh` (hard-coded Christian paths), `compute_laplace.sh` (docker, not on JURECA).
- `data/` files are git-annex links without content on the mount (`datalad get` on JURECA); `data_whole_brain/uniform_grid_02mm_Bxx_anchor_points_whole_brain.hdf5`.

## samplestuff (`samplestuff/cli.py`, API `conversion.py`)
Nearest-neighbour transfer (KDTree). Feature lists: `--include-features`, `--exclude-features`, `--separator ,`.
- `ann2anchor ANNOTATION_DB ANCHOR OUT` (`:224`): area label per 2D point from DB polygons. `--label-file JSON` (allowed labels), `--output-name labels`, `--bg-label bg`, `--include-side` (`{label}_{l|r}`), `--exclude-background`, `--annotation-include-file JSON` (`{"<brain>": {"<section>": [ids]}}`), `--annotation-label-key label` (or e.g. `project,internal_name`), `--annotation-label-separator _`. Needs attr `brain`; writes string feature + root attr **`label`** (singular; `bg` first). Nested polygons = holes → bg; first containing polygon wins. Empty DB folder → everything `bg`, no error.
- `volume2anchor VOLUME ANCHOR OUT` (`:143`): sample a NIfTI/HDF5 volume at 3D points (`--output-feature`, `--interpolation nearest|linear|cubic`, `--key-3d ras` to use a feature as coordinates, `--ignore-affine`, `--fill-value`, `--extrapolate`).
- `anchor2mask ANCHOR MASK_PATTERN OUT_PATTERN` (`:181`): paint each mask pixel (`--mask-values 1`) with the nearest point's feature → HDF5 pyramid per section (`--spacing 64`, `--distance-threshold µm`, `--argmax`, `--output-mask-prefix`; MPI over sections).
- `volume2mesh VOLUME MESH OUT` (`:20`), `mesh2volume MESHES... IN_VOLUME OUT_VOLUME FEATURE` (`:45`; always casts to int), `mesh2anchor MESH ANCHOR OUT` (`:70`), `mesh2mesh SRC TGT OUT` (`:89`), `anchor2mesh ANCHOR MESH OUT` (`:115`).
- API: `points.sample_points_with_points`, `volume.VolumeReader.create_reader(fname)`, `sample_volume_with_points(volume, affine, points, ...)`, `coloring.color_mask_by_points`.

## annotation_db (`anndb`)
- DB = folder: `structures.json`, `colors.json`, `image_sizes.json`, `metadata.json`, `annotations/Bxx/Bxx_SSSS_annotations.json` (`{id: {brain, section, name, project, side, polygon [[x,y]], spacing, space "1micron"|"20micron", label, internal_name, ...}}`). Names parse as `[project_]area_side[_onlyinner|_onlyouter][_index][_info]`.
- Snapshots are git submodules `db/anndb2003 … anndb20260415`; **empty unless initialised**: `git -C $GALAXY_ROOT/code/annotation_db submodule update --init db/<name>` (`anndb20260415` is missing from `.gitmodules`). An empty folder silently gives an empty DB.
- Python: `AnnotationDB(base_dir)` (`annotation_db/db.py:10`): `load_annotations(brain, section)` (`:255`), `get_annotations_for_sections` (`:322`), `annotation_iterator()` (`:220`), `find_structure(regex, project)` (`:169`), `get_image_size` (`:230`), `import_annotations(...)` (`:343`), context manager saves.
- CLI (`annotation_db/cli/anndb_cli.py`):
  - `anndb export masks DB OUTPUT_PATTERN` (`:462`): label masks as HDF5 pyramids + PNG (MPI). `--brains`, `--sections`, `--output-spacing 16`, `--labels a,b | --labels-file`, `--side both|left|right`, `--include-file`, `--prefix mask`, `--overwrite`.
  - `anndb export files DB OUT_DIR` (`:363`, MicroDraw JSON), `anndb export microdraw ...` (`:392`).
  - `anndb import files DB FILES...` (`:162`, MicroDraw JSON / OST XML), `import ost-index DB INDEX` (`:281`), `import transformations DB TRF...` (`:311`, 20 µm → 1 µm), `import microdraw|ost` (internal hosts/credentials).
  - `anndb setup structures DB CYTO_TABLE.xlsx` (`:47`), `setup image-size DB REFS...` (`:85`), `setup metadata DB --item K V` (`:132`); `db/setup_new_version.sh` builds a new snapshot (datalad).
  - `anndb clean remove-duplicates DB` (`:700`), `clean validity DB` (`:766`), `clean conflict DB [--threshold .2]` (`:842`) → reports in CWD.
  - `anndb microdraw import|export|delete ...` (`:933-999`).
- `scripts/greedy_sample_generation.py ANNOTATION_DB PATCH_SIZE OUT.hdf5`: atlas HDF5 sample file (key `boxes`) of patch centres inside annotations. `--status-filter publicP,publicDOI`, `--global-structure-filter`, `--spacing 16`, `--border-threshold 400` µm, `--max-points 50` per annotation, `--sections b:s-range`. Only `1micron`, non-`custom`, non-GapMap. MPI (run with srun). Also `create_structure_list.py`, `labels_from_structure_list.py`; `analysis/labels.json`, `annotation_include_list*.json`.

## colin (`colin/cli/colin_cli.py`)
- `colin colin2histo VOLUME T3D_AFFINE T3D_DEFORM T2D_AFFINE_PATTERN T2D_DEFORM_PATTERN OUT_PATTERN` (`:30`): Colin27 NIfTI (isotropic RAS) → per-section images. `--output-spacing 211.666667`, `--interpolation 1`, `--colin-linear`, `--brain`, `--orientation coronal|horizontal|sagittal`. Writes `<deform>_inverse.nii` next to the input transform (fails if read-only).
- `colin histo2colin INPUT_PATTERN T3D_AFFINE T3D_DEFORM T2D_AFFINE_PATTERN T2D_DEFORM_PATTERN OUT_VOLUME` (`:218`): sections → RAS NIfTI (`--aggregation-factor 1|2|4`).
- API `colin/transform.py` (`AffineTransform`, `DeformTransform`, `transform_{3d,2d}_{colin_to_histo,histo_to_colin}`, `vector_transform_*`), `colin/volume.py` (`ras_to_pil`, ...). Scripts: `create_ras_volume.py`, `combine_ras_sections.py`, `combine_pmap_*.py`, `link_missing_sections.py`, `ras_colin_to_1micron.sh` (RAS maps for histology = source of the `ras` channel), `pmap_colin_to_1micron.sh`.

## tseg
`tseg segment INPUT_PATTERN OUTPUT_PATTERN [--sections --high-spacing 16 --low-spacing 64 --verbose-output-dir DIR]` (`tseg/cli.py:33`): contrast enhancement → threshold → morphology → Chan–Vese → HDF5 pyramid labels `bg, cor, wm` (MPI over sections). Source has no entry point: `python -m tseg.cli segment ...` if the alias is missing.

## atlas3d (stale since 2025-07)
`atlas3d data preprocess-graph BRAINS... MESH_PATTERN OUT` (`atlas3d/cli/atlas3d_cli.py:23`, mesh → graph HDF5 with features/labels/pmaps/ras), `atlas3d data to-mesh GRAPHS... OUT FEATURES` (`:338`), `atlas3d data graph2anchor GRAPHS... ANCHOR OUT FEATURES` (`:383`), `atlas3d gnn predict GRAPHS... RUN_DIR [--amp --batch-size --output-key predictions]` (`:435`). Training: atlas `mode="graph"`.

## atlaslib (library)
- `Image.get_image(filename, prefix="/", spacing=None, h5py_args=None, ...)` (`atlaslib/image.py:148`): `.h5/.hdf5` → `Hdf5Image`, `*.zarr` → tensorstore (`ATLAS_ZARR_BACKEND=zarr` for zarr-python), `.zarr.zip`, `.mnc`, `.tif` → `TiffImage`, other/ndarray → `MemoryImage`. All: `get_crop(bbox=None, spacing, dtype=None, interpolation=3)` (`:637`), `get_size(spacing)` → (h, w), `.spacing`, `.scales`, `.attrs`.
- HDF5 pyramid: `<prefix>/pyramid/00, 01, ...` + attrs `spacing`, `scales`, `maxintensity`, `labels`, `brain`, `slice`, `bbox`. Write with `atlaslib.io.array_to_hdf5_pyramid(fname, array, spacing, prefix="/", interpolation=0, labels=None, num_levels=8, ...)` (`io.py:15`), `array_to_pyramid` (`:332`, TIFF or HDF5 by extension), `array_to_tiff_pyramid` (`:203`).
- `BoundingBox(center, w, h, spacing=1.0)` (`bounding_box.py:9`; center (x, y); careful: `get_hw()` returns (h, w)), `from_corners(pt1, pt2, spacing)`, `set_to_spacing`, `rescale`, `pad`, `crop_from_array`, `contains_point`, `to_json`/`from_json`.
- Filename "patterns" (`files.py`): `get_filename_from_template(template, section_number, brain=None)` (`:68`) replaces the LAST run of section digits in a concrete example path and, with `brain`, every `B<digits>` — and every capital `B` (`/BigBrain/` breaks). `get_section_number_from_string` (`:7`), `get_brain_from_string` (`:44`), `find_sections_by_pattern(template)` (`:119`, globs). `ImageReader(path_pattern, prefix)` (`io.py:419`) switches to `str.format` mode if the pattern has `{brain}`/`{section}`.
- `hdf5.open_file(fname, mode, h5py_args, mpio_comm)` (`hdf5.py:56`), `get_minimal_cache_settings()` (`:6`).
- Staging: `io.stage_zarr_to_ram(src, stage_dir="/dev/shm")` (`:696`, metadata copied, chunks symlinked; needs rsync, coreutils ≥ 9.3), `stage_split_hdf5` (`:617`), `node_lock(path)` (`:763`).
- click types (`click.py`): `SliceParamType`, `BrainParamType` (`1`, `B01`, `pm54491`), `ImagesParamType` (`"F,k=v;F2,..."`), `NamedPathParamType` (`name:path`).
- `neuro.pm_to_brain_mapping()` / `pm_to_brain_id("pm54491") → 1` (`neuro.py:6,45`).
- `transformation.Transformation.from_file(.txt elastix | .json)` (`:430`), `RecursiveTransformation("…{brain}…{slice}…")` (`:237`), `get_affine_transformation(src, dst)` (`:887`).
- `combat.PyCombat().fit_transform(data, batch)` (`combat.py:10`; rows = features; needs `inmoose`) — batch-effect (brain) harmonisation.
- Also `polygons.rasterize_polygons`, `slurm.get_remaining_job_runtime()`, `zarr.ResilientWrapperStore`, `annotations.Annotations` (MicroDraw/SectionTracer), `logging.get_logger`.

## typhon / atlasmpi / dms / rambo (libraries)
- **atlasmpi**: real mpi4py if any of `OMPI_COMM_WORLD_SIZE`, `PMI_SIZE`, `PMIX_RANK` is set or `ATLASMPI_ENABLE=0`; else stub (rank 0, size 1). Stub lacks `reduce`, `gather`, `scatter`, `send/recv`, `UNDEFINED` → scripts using them (`refine_points_by_laplace.py`, `tissue_histogram.py`) need `srun`.
- **typhon**: `distribute.get_elements_for_process(elements, rank=None, size=None, mode="round_robin"|"linear")` (`:72`, generator → wrap in `list()`), `subdivide_array`/`reassemble_subdivided_array`; `cluster.make_node_communicator()`, `get_node_info()`, `read_physical_gpus()`; `shared_memory.make_shared_memory_array(shape, dtype)`; `algorithms.apply_to_list(elements, f)` (`apply.py:6`, `f(elem, idx)`), `apply_to_chunks(...)` (`:60`), `connected_components`; `io.hdf5_to_subdivided_array`.
- **dms**: `DMS(timeout=None)` (`dms/dms.py:17`) + `keep_alive()`. Timeout = arg, else `DMS_TIMEOUT` env (s), else 600. On timeout: callbacks, then `scancel --signal=TERM <job>.<step>` under Slurm, else `kill -9`. atlas `dl train --dms` uses it.
- **rambo**: `RAMBooster(comm=None)` (`rambo/ram_booster.py:37`): `stage(path)` → copy in `/dev/shm/<uuid>`, `unstage`, `clear`. Files only; pass a node communicator on multi-node runs. Prefer atlaslib staging.
