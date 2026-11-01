#!/bin/bash -x
# --------------------------------------------------------------------------
# Train an atlas experiment (DDP over all GPUs of all nodes).
# Usage:   sbatch --nodes=<N> --time=HH:MM:SS train.sbatch <exp_or_run> [more atlas dl train args]
# Resumes automatically from the run's latest training_state: resubmit the same command after a timeout.
# Fill <...> from local-setup.md. Submitting uses compute budget: confirm with the user first.
# --------------------------------------------------------------------------
#SBATCH --account=<account>
#SBATCH --partition=<gpu partition>
#SBATCH --gres=gpu:4
#SBATCH --tasks-per-node=64
#SBATCH --threads-per-core=2
#SBATCH --output=train-job-out.%j
#SBATCH --error=train-job-err.%j
#SBATCH --signal=TERM@120
##SBATCH --mail-user=<email>
##SBATCH --mail-type=FAIL,END

export GALAXY_ROOT=${GALAXY_ROOT:-<galaxy root>}
module purge
source ${GALAXY_ROOT}/init.sh
module load atlas
eval $(atlas_bind_dev)            # use $GALAXY_ROOT/code/* dev checkouts; drop this line to use the container's packages

export CUDA_VISIBLE_DEVICES="0,1,2,3"   # atlas counts GPUs from this; unset = 1 GPU/node
export DMS_TIMEOUT=300                  # dead man's switch: kill job after 5 min without progress
# InfiniBand flakiness fixes
export NCCL_IB_TIMEOUT=200 UCX_RC_TIMEOUT=16s NCCL_IB_RETRY_CNT=30 NCCL_IB_RETURN_ASYNC_EVENTS=0 NCCL_SOCKET_NTHREADS=4

MAX_RETRIES=5
for RETRY in $(seq ${MAX_RETRIES}); do
    # 64 tasks/node x 4 CPUs: 4 GPU masters + 60 data-loading slaves per node
    srun --cpus-per-task 4 atlas dl train "$@" --distribute
    RETURN_CODE=$?
    [[ ${RETURN_CODE} == 0 ]] && break
    echo "Attempt ${RETRY}/${MAX_RETRIES} failed (exit ${RETURN_CODE})"
done
exit ${RETURN_CODE}
