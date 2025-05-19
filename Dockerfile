######################## stage 1: build ########################
FROM pytorch/pytorch:2.6.0-cuda12.4-cudnn9-devel AS builder

ARG FLASH_ATTN_WHEEL_URL=https://github.com/mjun0812/flash-attention-prebuild-wheels/releases/download/v0.0.8/flash_attn-2.7.4.post1+cu124torch2.6-cp311-cp311-linux_x86_64.whl
ARG MAX_JOBS=4

# ------ parallelism & GPU target ---------------------------------
ENV MAX_JOBS=${MAX_JOBS} \
    CMAKE_BUILD_PARALLEL_LEVEL=${MAX_JOBS} \
    NINJAJOBS=${MAX_JOBS} \
    TORCH_CUDA_ARCH_LIST="8.9" \
    VLLM_FA_CMAKE_GPU_ARCHES="89-real" \
    VLLM_FLASH_ATTN_VERSION=2

# ------ system deps ---------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends git patchelf ninja-build kmod && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip wheel build "setuptools<77" auditwheel

# ------ pull source ---------------------------------------------
RUN git clone --depth 1 -b v0.8.5.post1 https://github.com/vllm-project/vllm.git /src/vllm
WORKDIR /src/vllm

# strip OpenTelemetry to keep wheel metadata clean (optional)
RUN sed -i '/opentelemetry/d' pyproject.toml requirements/common.txt

# fix license metadata
RUN sed -i 's/license = "Apache-2.0"/license = { file = "LICENSE" }/' pyproject.toml
RUN sed -i '/license-files/d' pyproject.toml

# ------ pre-install Flash-Attention-2 ---------------------------
RUN pip install --no-cache-dir ${FLASH_ATTN_WHEEL_URL}

# ------ build vLLM wheel (only core kernels compile) ------------
RUN pip install -r requirements/build.txt -r requirements/cuda.txt
RUN python -m build --wheel --no-isolation --skip-dependency-check

# # # repair it so the tag matches your image's glibc (manylinux_2_17)
RUN auditwheel repair \
    dist/vllm-0.8.5.post*.whl \
    --wheel-dir /wheelhouse \
    --plat manylinux_2_35_x86_64 \
    --exclude 'libtorch*.so*' \
    --exclude libc10*.so*  \
    --exclude libcuda.so.1

# Final stage: export only the wheel
FROM scratch AS export
COPY --from=builder /wheelhouse/vllm-*.whl /
