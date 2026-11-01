# atlas data sources and sample files

Paths relative to `$ATLAS_SRC/atlas/` (atlas `v0.3.0-6-gc64050cf`). Classes in `configuration/data_source.py` (imported as `ds` in configs); batch-building code in `data/batch_iterator.py` (dispatch `:702-752`).

## Common constructor args (every DataSource, `data_source.py:9`)
`name`, `sample_index=None` (pick a view when the sampler yields tuples), `affine_transform_group`, `intensity_transform_group`, `cross_channel_transform_group` (same group = same random augmentation, e.g. image + its label map; different groups = independent views), `samples_key_in` / `samples_key_out` (filtered sample lists, see SampleFilter).

## Classes
| class (line) | args beyond the common ones | yields |
|---|---|---|
| `ImageDataSource` (`:176`) | `channels, spacing, size, data_format="NCHW", num_channels=None, channel_index=None, affine_sample_key, transform=True` | float image `(B,C,size,size)`. `num_channels` must be > `len(channels)`; `channel_index` needs one channel + a `channels` dataset attr (reordering looks buggy, `batch_iterator.py:917`) |
| `StackDataSource` (`:327`) | `channels, spacing, size, offsets` (must contain 0), `offset_tolerance=0, data_format` (N,C,H,W,D or S), `blacklist/whitelist, transformation_parameters, allow_duplicates` | neighbouring sections `(B,D,C,H,W)`; `S` folds stacks into the batch (CPC) |
| `LabelDataSource` (`:488`) | `labels, spacing, size, count_labels=True` | dense label map (int64) for segmentation |
| `BinnedLabelDataSource` (`:540`) | `channel, bins, spacing, size` | dense labels by binning a channel |
| `SequentialLabelDataSource` (`:602`) | `repeat=1` | `arange(B)` instance labels (SimCLR-style), shifted per rank |
| `SampleLabelDataSource` (`:653`) | `labels, unknown_value=None, label_key="label"` (str or list), `label_format="{label}"` | `(B,1)` index of the sample's label in `labels`; unknown raises unless `unknown_value` |
| `SampleMultiLabelDataSource` (`:855`) | `labels, key, label_separator="+"` | `(B, len(labels))` multi-hot |
| `SampleAttributeDataSource` (`:700`) | `fields=[{key, kind:"continuous"|"categorical", dim, categories, normalize: std or (mean,std), required}], unknown_category_value, missing_value=0.0` | `(B, D)` float32 (flow-matching conditioning) |
| `ProbabilityDataSource` (`:783`) | `pmap_names, mode="normalize", pmap_data_key="pmap", pmap_names_key="pmaps"` (tuple = literal names), `noise_std, normalize_eps` | `(B, n)` from sample attributes. modes `normalize`, `l2`, `argmax`→`(B,1)` int, `sample`→`(B,1)`, `noise`, `None` (raw: CytoNet RAS coordinates as soft contrastive labels) |
| `DomainDataSource` (`:945`) | — | `(B,)` from `sample.domain` (domain sampler) |
| `HistogramDataSource` (`:899`) | `data_source, num_bins=256, bin_range=(0,1), normalize=True, remove_source=False` | histogram of another source |
| `TransformationParamDataSource` (`:972`) | `param_keys, channel, intensity_transform_group, affine_transform_group, normalize_per_key` | vector of applied augmentation params (LSA input) |
| `SampleFilterDataSource` (`:122`) | `key, values, invert=False, missing=False` | no tensor: writes the filtered sample list under `samples_key_out or name`; later sources read it with `samples_key_in=name`. Mixed-modality batches; must come **before** its consumers; consumers don't set `sample_index` again. Empty selections → `(0,C,H,W)` |
| `LambdaDataSource` (`:1022`, abstract) | subclass, implement `make_data(batch, data_source, batch_iterator)` | custom, mutates batch |
| `PretrainImage` / `DistanceCL` / `PretrainPseudolabel` (`:85-110`) | dist_pretrain only, partly broken | avoid |

Network inputs may only be Image, Stack, TransformationParam, Probability sources (`get_input_shapes` `:1138`). `InputOutputMapping(input, output=None, optional=None)` (`:1060`): names (str or list) of data sources; output order matters for multi-output modes.

## Sample (`data/sampler.py:9`)
Dict-backed object with attribute access: `center` (x,y at `spacing`), `spacing`, `brain`, `slice_no`/`slice`, any extra attrs (`label`, `ras`, `modality`, ...). `Sample.deserialize(dict|list)` (`:100`), `.to_dict()` (`:160`), `.create_bbox_around(height, width, spacing)` (`:128`) → atlaslib `BoundingBox`, `.to_image_specification(keys)` (`:58`).

## Sample-file formats
- **HDF5** (training `hdf5`/`hdf5_nearest` samplers, predict-points): `<key>/<subidx>/<column>[N]`, key usually `boxes`, subidx `0` (more groups `"1","2"` = multi-view tuples → each data source needs `sample_index`). Required columns: `center` (N,2), `spacing`, `brain`, `slice_no` (or `slice`). Extra columns → Sample attributes. Group attrs attachable (`hdf5_file_sampler_attach_file_attributes`).
  - Read: `Hdf5SampleFile(fname, key="boxes", h5py_args=None, cache=False)` (`:2008`): `len()`, `[i]` (adds `index`, decodes bytes; list if several sub-groups), `.file_attributes`, `.get_sample_counts()`.
  - Write: `Hdf5SampleFile.write_samples_to_hdf5(out, samples, key="boxes", **group_attrs)` (`:2112`): overwrites the file (`"w"`); columns from the first sample; drops `info` and None-valued columns; raises on `area_record` (delete it first).
- **JSON** (`file` sampler): `{"samples": [{center, spacing, brain, slice_no, ...}]}`; generate with `atlas exp samples create CONFIG OUT N`. predict-points cannot read JSON (convert to HDF5).
- **JSON/HDF5 test sets** (`test` sampler): `{"boxes": [...], "sampler_params": ...}`; `atlas.testing.parse_test_set_file(fname, key="boxes")` (`testing.py:43`), `write_test_set_file(samples, fname, sampler_params)` (`:85`), `TestSet(files|callable, size, key="boxes")` (`:132`), `atlas exp test create`.
- Convert sample file ↔ AnchorPoints: `b3 convert samples2anchor IN OUT_PATTERN` / `b3 convert anchor2samples INPUTS... OUT` (companions.md).
- **brain3d AnchorPoints** (predict-points input/output): per-section groups `{section:06d}/` with `2d` (x,y at spacing 1), optional `3d`, features (`labels` int index into attr `labels`, ...), attr `brain`. See companions.md.
- Minimal HDF5 example (from `tests/test_hdf5_nearest_neighbor_sampler.py`): `boxes/0/{brain, slice_no, center, spacing, ras}`.

## Image files read by `FileParams`
HDF5 pyramids (`pyramid/00..`, picked by requested spacing; optional per-section dataset `"{slice:04d}"`), Zarr v2/v3 (tensorstore; walked without zarr-python), TIFF, in-memory. Labels in file attr `labels`, colours in `colors`. Inspect any file with `atlas img info FILE`.
