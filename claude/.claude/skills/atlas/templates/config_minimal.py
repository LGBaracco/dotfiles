# Minimal atlas config: patch classification (one label per patch) from an HDF5 sample file.
# Copy to <exp>/config.py (or `atlas exp new NAME --config config_minimal.py`), edit the CAPS constants,
# then `atlas exp run new <exp>` and train with templates/train.sbatch.
# Reference for every option: references/config.md. Derived from examples/config/config_cytonet_finetune.py.

# Module level: constants only. This file is imported on every MPI rank, incl. CPU-only data loaders.
IMAGE_PATTERN = "/path/to/B{brain:02d}/B{brain:02d}_2micron_histology.hdf5"  # {brain}, {slice} or any {key} from the samples
IMAGE_DATASET = "{slice:04d}"                 # dataset inside the HDF5 file ("/" if one section per file)
TRAIN_SAMPLES = "/path/to/train_samples.hdf5"  # boxes/0/{center, spacing, brain, slice_no, label}
LABELS_JSON = "/path/to/labels.json"           # list of label names; sample attr `label` must be one of them
INPUT_SIZE = 1024                              # patch size in px
INPUT_SPACING = 2                              # µm/px of the patch
TOTAL_BATCH_SIZE = 256                         # over all GPUs
ITERATIONS = 20000


def make_training_parameters(**kwargs):
    import json
    from atlas.configuration import config
    from atlas.configuration import data_source as ds
    from atlas.data.image_provider import CHANNEL_HISTOLOGY
    from atlas.experiments import parallel
    from atlas.torch.optimizers import WeightDecaySelector

    with open(LABELS_JSON) as f:
        labels = json.load(f)

    # Image location. FILE_PARAMETERS is a shared class-level dict: set fields in place.
    fp = config.ImageProviderParams.FILE_PARAMETERS[CHANNEL_HISTOLOGY]
    fp.fname = IMAGE_PATTERN
    fp.dataset = IMAGE_DATASET
    fp.standardize, fp.mean, fp.std = True, 0.5, 0.5
    # HDF5 chunk cache must hold >= 1 chunk, else reads go row by row
    fp.h5py_args = {"rdcc_nbytes": 8 * 1024 * 1024, "rdcc_nslots": 51, "rdcc_w0": 1}

    # batch_size is per GPU master
    num_gpus = parallel.NUM_MASTERS if parallel.IS_DISTRIBUTED else 1
    assert TOTAL_BATCH_SIZE % num_gpus == 0, f"{TOTAL_BATCH_SIZE} not divisible by {num_gpus} GPUs"
    batch_size = TOTAL_BATCH_SIZE // num_gpus

    lr = [config.LearningRateParams(learning_rate=1e-3)]
    transformation_parameters = config.TransformationParams(
        random_mirroring=True,
        random_discrete_rotation=True,
        brightness_augmentation=True,
        contrast_augmentation=True,
    )

    return config.TrainParams(
        mode="segmentation",                   # also used for patch classification (logits (B, C))
        iterations=ITERATIONS,
        snapshot=1000,
        num_classes=len(labels),
        sync_batch_norm_statistics=True,
        input_output_mapping=ds.InputOutputMapping(input="sample", output="labels"),
        optimizer_params=config.OptimizerParams(
            optimizer="adamw",
            learning_rate_params=config.LearningRateParamsPerParamGroup(lr, lr),
            param_group_selectors=[WeightDecaySelector(), WeightDecaySelector(inverse=True)],
            weight_decay=[1e-4, 0.0],
            distributed_learning_rate_scaling=False,
            amp_params=config.AmpParams(),
        ),
        network_params=config.NetworkParams(make_network=make_network),
        iterator_params={
            config.TRAIN_SPLIT: config.IteratorParams(
                batch_size=batch_size,
                data_sources=[
                    ds.ImageDataSource("sample", channels=CHANNEL_HISTOLOGY, spacing=INPUT_SPACING, size=INPUT_SIZE,
                                       affine_transform_group=0, intensity_transform_group=0),
                    ds.SampleLabelDataSource("labels", labels=labels),
                ],
                image_provider_params=config.ImageProviderParams(transformation_parameters=transformation_parameters),
                sampler_params=config.SamplerParams(
                    sampler_mode="hdf5",
                    hdf5_file_sampler_file=TRAIN_SAMPLES,
                    file_sampler_samples_key="boxes",   # default "samples" is wrong for HDF5 sample files
                ),
            ),
        },
    )


def make_network(**kwargs):
    from atlas.torch.models.resnet import ResNet, get_resnet_params

    input_shape, *_ = kwargs["input_shape"]     # one shape per input: (None, C, H, W)
    params = get_resnet_params("resnet18", memory_efficient=True)
    params.output_features = kwargs["num_classes"]  # global avg pool + linear head
    return ResNet(input_channels=input_shape[1], params=params)
