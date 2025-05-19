# Dockerfile.builder
FROM pytorch/pytorch:2.6.0-cuda12.4-cudnn9-devel AS builder

# system deps that auditwheel needs
RUN apt-get update && apt-get install -y patchelf git kmod && rm -rf /var/lib/apt/lists/*

# Python build dependencies
RUN pip install --upgrade pip wheel build "setuptools<77" auditwheel

# (OPTIONAL) clone & patch: strip out the OpenTelemetry extras so they
# don't get recorded in the wheel metadata
RUN git clone --depth 1 -b v0.8.5.post1 https://github.com/vllm-project/vllm.git /src/vllm

WORKDIR /src/vllm

RUN sed -i '/opentelemetry/d' pyproject.toml requirements/common.txt
RUN sed -i 's/license = "Apache-2.0"/license = { file = "LICENSE" }/' pyproject.toml
RUN sed -i '/license-files/d' pyproject.toml

# Install build and CUDA dependencies
RUN pip install -r requirements/build.txt -r requirements/cuda.txt

# # build the wheel
RUN python -m build --wheel --no-isolation --skip-dependency-check

# # repair it so the tag matches your image's glibc (manylinux_2_17)
RUN auditwheel repair \
    dist/vllm-0.8.5.post1-*.whl \
    --wheel-dir /wheelhouse \
    --plat manylinux_2_17_x86_64
