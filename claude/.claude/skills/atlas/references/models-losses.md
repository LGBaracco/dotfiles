# atlas models, losses, SSL, optimizers, metrics

Paths relative to `$ATLAS_SRC/atlas/torch/` (atlas `v0.3.0-6-gc64050cf`). If a line moved: `rg -n "class <Name>|def <name>" $ATLAS_SRC/atlas/torch`.
Use from `make_network(**kw)` in a config (config.md). Input channels come from `kw["input_shape"][0][1]`.

## Models (`models/`)
**ResNet family** (`resnet.py`)
- `get_resnet_params(name, **kw)` (`:614`): `resnet18|34|50|101|152`, `resnext50_32x4d`, `resnext101_32x8d`, `wide_resnet50_2|101_2`. Classes `ResNet18 ... WideResNet101_2` (`:719-813`).
- Low level: `ResNet(input_channels, ResNetParams(channels, num_layers, strides, bottleneck_channels, head_params=ResNetHeadParams(...), output_features, norm="batch_norm", groups, zero_init_residual, memory_efficient, dropout_rate, channel_multiplier))` (`:511`, `:70`, `:21`). `head_params=None`, `output_features=None` → bare body.
- Block names `conv_{block}_{layer}` (e.g. `conv_4_3`) → used in hook paths (`encoder.body.conv_4_3`) and feature-regulariser layers.

**DenseNet** (`densenet.py`): `get_densenet_params("densenet121|161|169|201")` (`:371`), `DenseNet121/161/169/201`, `DenseNet(input_channels, DenseNetParams)` (`:284`).

**ConvNeXt** (`convnext.py`): `convnext_tiny|small|base|large(weights=None, input_channels=, memory_efficient=)` (`:296-383`), `ConvNeXt(block_setting=[CNBlockConfig(in,out,n)], ...)` (`:91`).

**ViT** (`transformers/vit.py`)
- `ViTBody(ViTConfig(...))` (`:693`, config `:55`): `img_size=2048, patch_size=16, in_channels=1, embed_dim=768, num_attention_heads, num_encoder_layers, mlp_dim=3072, qkv_bias, gradient_checkpointing`.
- `pool`: `mean|patch_mean`, `cls`, `cls_mean_concat`, `None|"tokens"`. `position_embedding_type`: `learned|rope|learned_rope|none`. Also register tokens, `qk_norm="l2"|"rmsnorm"`, `use_sdpa`, `ffn_type="mlp"|"swiglu"`, `layer_scale_init_value`, `drop_path_rate`, `norm_type`, `return_dict` (→ `ViTOutput` `:39`), `output_intermediate_layers`, `interpolate_absolute_positional_embeddings`.
- CytoNet hybrid: conv head → ResNet50 body → `ViTBody(img_size=32, patch_size=1, pool="cls")` (examples/config/config_cytonet_pretrain.py).

**Other transformers**: `SimpleViT(image_size, patch_size, num_classes, dim, depth, heads, mlp_dim, channels=3)` (`transformers/simple_vit.py:92`); `swin_t|s|b`, `swin_v2_t|s|b|l|h` and `SwinTransformer(...)` (`transformers/swin.py:451,567-659`); `CvT(CvTConfig(in_channels=1, ...))` (`transformers/cvt.py:168,206`).

**Segmentation U-Nets** (`segmentation/`)
- `UNet(input_channels, num_classes, down_params, bottom_params, up_params, init_func, final_kernel_size=1, ...)` (`unet.py:12`); params in `unet_parts.py`: `UNetPathParams(filters, kernel_size=3, block_depth=2, padding=0, norm="batch_norm", drop_out, order="conv_norm_act_drop")` (`:29`), `UNetDownPathParams` (`:68`), `UNetBottomPathParams` (`:116`), `UNetUpPathParams` (`:124`).
- Multi-scale `unet_multiscale.UNet(input_channels:list, input_spacings:list, ...)` (`unet_multiscale.py:78`); `UNetMultiStream` (`unet_multi_stream.py:15`); `AtlasAwareUNet(histology_input_channels, atlas_input_channels, ...)` (`atlas_aware_unet.py:12`); `UNetSegDepth` → `(seg, depth)` for `aux_depth_regression` (`multitask.py:51`); `DistUnet` (`unet.py:80`).

**GANs**: CycleGAN `define_G(input_nc, output_nc, ngf, netG="resnet_9blocks|resnet_6blocks|unet_128|unet_256", norm)` (`gan/cyclegan.py:98`), `define_D(input_nc, ndf, netD="basic|n_layers|pixel")` (`:141`); StarGAN `Generator(conv_dim, c_dim, repeat_num, input_channels=1, output_channels=1)` (`gan/stargan.py:26`), `Discriminator(image_size=128, ...)` (`:70`).

**Generative**: `FlowMatchingUNet(input_channels, base_channels=64, channel_multipliers=(1,2,4,4), num_res_blocks=2, condition_data_source=None, condition_dim=256, conditioning_mode="film"|"cross_attention"|"film+cross_attention", cross_attention_resolutions=(32,16,8), input_size)` (`generative/flow_unet.py:25`); features `down_i`, `middle_i`, `up_i`. Sampling: `torch/generative/flow_matching.py:22 sample_flow_matching(model, shape, condition, steps=50, method="heun", guidance_scale=1.0)`.

**GNN** (needs torch_geometric): `GNN(input_channels, hidden_channels, output_channels, gnn_module)` (`gnn.py:214`), modules `GATModule|SAGEModule|GINModule|GENModule|MLPModule`.

**Parts** (`parts/`): `ConvModule(in, out, kernel_size, stride, padding, norm="batch_norm"|"instance"|"group"|"layer", activation, drop_out, order, dim=2)` (`conv.py:110`), `PoolModule` (`pool.py:7`), `UpsamplingModule`, `ShortcutConnection|ResidualConnection|DenseConnection` (`shortcut.py`), `SiameseModule` (`composition.py:8`), `GaussianNoise`, `CenterCropModule` (`shape.py:7`), conditioning `SinusoidalTimeEmbedding|ConditionEncoder|FiLM|CrossAttention2d` (`conditioning.py`), `convert_safe_norm`, `SafeNorm*` (`norm.py`).

**Utilities**: `classification/base.py:7 Linear(in_shape, out_features)`; `init.py:7 default_init`; `checkpoint.py:95 checkpoint(fun, *args, cp_modules=None)` (gradient checkpointing with BN-momentum fix); `parameters.py` `freeze_parameters` `:6`, `lock_normalization_statistics` `:17`, `finetune` `:44`; `io.py:82 load_weights(model, weights, mapping=None, return_missing, device, key)`, `:151 get_model_device`.

## Losses (`loss/loss.py:269 setup_loss_operation(loss_type, weighted=True, loss_kwargs)`)
| `loss_type` | class |
|---|---|
| `categorical_cross_entropy`, `cross_entropy`, `cross_entropy_loss` | `nn.CrossEntropyLoss` |
| `dice_loss`, `dice`, `dice_score`, `jaccard_index` | `DiceLoss` (`:206`) |
| `focal` | `FocalLoss(gamma=2)` (`:484`) |
| `mse`/`l2`, `rmse` (`:250`), `mae`/`l1`, `huber`/`huber_loss`/`smoothl1loss` | regression |
| `smile` | `SMILELoss(unknown_index=-1)` (`:719`), BCE with missing annotations |
| `evidential` (`:324`), `distance` (`:1157`), `simsiam` (`:517`), `byol` (`:565`), `cpc` (`:787`) | mode-specific |
| GAN modes `lsgan|vanilla|wgangp` | `GANLoss` (`:647`) |
| any `nn.Module` subclass | used directly |
With `weighted=True` the loss is wrapped in `SpatiallyWeightedLoss` (`:73`, accepts only `reduction`). `"contrastive"` here → NameError (contrastive trainer builds its own).

**Contrastive** (`loss/contrastive.py`)
- `ContrastiveLoss` (`:450`), kwargs via `loss_kwargs` (NOT `temperature`, the trainer passes `contrastive_loss_temperature`): `distributed=False` (gather negatives across GPUs), `label_similarity="equal"|"dot"|"harmonic"|"euclidean"` (`:73`), `label_similarity_transfer_function` (callable on the similarity matrix), `weight_exponent`, `weight_threshold`, `distance_threshold`, `compute_dtype="fp32"|"fp16"|"bf16"`, `learnable_temperature`, `distributed_block_size`, `weight_denominator_by_inverse_positive_weight`. `forward(x, labels)` with labels `(B,)` or `(B,L)` (soft labels like RAS coordinates).
- `DeepSupervisionContrastiveLoss(loss, weights, main_key="output")` (`:574`); `RingContrastiveLoss` (`:642`, exact ring-streamed distributed; not selectable via `loss_type`); `LegacyContrastiveLoss` (`:1091`, `loss_type="legacy_contrastive"`, memory banks); `MemoryBank` (`:1339`); `concat_all_gather` (`:1436`).
- Flow matching: `loss/flow_matching.py:17 LinearFlowMatchingObjective`; `loss/feature_regularizer.py:85 FeatureRegularizer`.

## SSL methods (`ssl/methods.py`; `mode="ssl"`, `ssl_method`, `ssl_method_params`)
| method | params (defaults) | checkpoint |
|---|---|---|
| `mae` (`:295`) | `patch_size=16`, `decoder_hidden_dim`, `decoder_layers=2`, `mask_ratio=.75` | `model` |
| `dino` (`:359`) | `output_dim=65536`, `hidden_dim`, `head_layers=3`, `use_batch_norm`, `student_temperature=.1`, `teacher_temperature=.04`, `center_momentum=.9`, `teacher_momentum=.996`; several input sources = views | `model`, `teacher_model` |
| `ibot` (`:442`) | dino + `patch_size`, `output_dim=8192`, `token_hidden_dim`, `mask_ratio=.4`, `patch_loss_weight=1` | `model`, `teacher_model` |
| `dinov2` (`:550`) | iBOT core objective | `model`, `teacher_model` |
| `jepa` (`:571`) | `patch_size`, `predictor_hidden_dim`, `mask_ratio=.25`, `target_momentum=.996` | `model`, `target_backbone` |
Any method: `contrastive_aux={enabled, weight=1, temperature, projection_dim=256, hidden_dim, head_layers=2, loss_kwargs, unmasked_forward, use_all_views}` (`:136`). Add methods with `ssl/registry.py:11 register_ssl_method(name, cls)`. Helpers: `ssl/heads.py` (`MLPHead`, `TokenHead`, `MAEDecoder`), `ssl/losses.py`, `ssl/masking.py`.

## Optimizers (`optimizers/`)
- `optimizers.py`: `create_optimizer` (`:34`; sgd, adagrad, rmsprop, adadelta, adam, adamw), `create_loss_scaler` (`:63`), `setup_optimizer_parameter_groups` (`:117`; lr/weight_decay/momentum/betas per group), `ParameterSelector` (`:226`), `WeightDecaySelector` (`:235`), `CombinedParameterSelector` (`:364`).
- `lars.py`: `LARS(optimizer, trust_coefficient=.02, clip=True, eps=1e-8)` (wraps any optimizer; enable with `OptimizerParams(lars_enable=True)`).
- `lr_scheduler.py:9 AtlasLearningRateScheduler` (policies in config.md §5).

## Metrics (`metrics.py`)
`setup_metrics_operations` (`:7`) names: `accuracy`, `precision`, `recall`, `f1|f1_score`, `iou|jaccard|jaccard_score`, `mse`, `mae`, `accuracy_with_tolerance|threshold_accuracy`, `accuracy_by_threshold|segmentation_accuracy`, `confusion_matrix` (always computed). Unknown names assert. Also `compute_confusion_matrix` (`:53`), `compute_metrics_from_predictions` (`:120`).

## Distributed / memory
- `distributed/diffdist/`: autograd-aware `send/recv/broadcast/gather/scatter/all_gather`, `reduce_scatter`.
- `memory.py:208 BatchStager` (moves batches to GPU; LabelDataSource → long), `:18 data_to_device`.
- Sync BN: `TrainParams(sync_batch_norm_statistics=True)` (only when distributed; `torch/training/trainer.py:253`).
