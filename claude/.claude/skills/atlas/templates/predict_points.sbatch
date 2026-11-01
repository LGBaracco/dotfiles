#!/bin/bash -x
# --------------------------------------------------------------------------
# Per-point features with `atlas dl predict-points`, one run per points file.
# Usage:   NAME=frozen OUTPUT_CONFIG=backbone:encoder sbatch --nodes=1 --time=02:00:00 predict_points.sbatch <exp> a.hdf5 [b.hdf5 ...]
# Output:  <exp>/active_run/results/predictions/<NAME>/<basename(points file)>  (existing files are overwritten)
# Env:     NAME (default frozen), OUTPUT_CONFIG (default backbone:encoder; "name:attr,name2:@hook:mod.path"),
#          BATCH_SIZE (default 64), EXTRA_ARGS (e.g. "--max-points 100" for a smoke test).
# Fill <...> from local-setup.md. Submitting uses compute budget: confirm with the user first.
# --------------------------------------------------------------------------
#SBATCH --account=<account>
#SBATCH --partition=<gpu partition>
#SBATCH --gres=gpu:4
#SBATCH --tasks-per-node=64
#SBATCH --threads-per-core=2
#SBATCH --output=predict-job-out.%j
#SBATCH --error=predict-job-err.%j
#SBATCH --signal=TERM@120
##SBATCH --mail-user=<email>
##SBATCH --mail-type=FAIL,END

export GALAXY_ROOT=${GALAXY_ROOT:-<galaxy root>}
module purge
source ${GALAXY_ROOT}/init.sh
module load atlas
eval $(atlas_bind_dev)

export CUDA_VISIBLE_DEVICES="0,1,2,3"
export DMS_TIMEOUT=300

NAME=${NAME:-frozen}
OUTPUT_CONFIG=${OUTPUT_CONFIG:-backbone:encoder}
BATCH_SIZE=${BATCH_SIZE:-64}
EXP=$1
shift

FAILED=0
for POINTS in "$@"; do
    echo "=== ${POINTS}"
    # Points are spread over ranks automatically (no --distribute)
    srun --cpus-per-task 4 atlas dl predict-points "${EXP}" "${POINTS}" \
        --output-configuration "${OUTPUT_CONFIG}" \
        --amp --batch-size "${BATCH_SIZE}" --name "${NAME}" ${EXTRA_ARGS}
    if [[ $? != 0 ]]; then
        echo "predict-points failed for ${POINTS}"
        FAILED=1
    fi
done
exit ${FAILED}
