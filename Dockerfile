ARG CUDA_VERSION=12.6.1
FROM nvidia/cuda:${CUDA_VERSION}-cudnn-devel-ubuntu22.04

ARG BUILD_TYPE=all
ARG DEEPEP_COMMIT=b92d0d4860ce6866cd6d31bfbae937f9a7a3772b
ARG CMAKE_BUILD_PARALLEL_LEVEL=2
ENV DEBIAN_FRONTEND=noninteractive \
    CUDA_HOME=/usr/local/cuda \
    GDRCOPY_HOME=/usr/src/gdrdrv-2.4.4/ \
    NVSHMEM_DIR=/sgl-workspace/nvshmem/install
# Add GKE default lib and bin locations.
ENV PATH="${PATH}:/usr/local/nvidia/bin" \
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/nvidia/lib:/usr/local/nvidia/lib64"

    

RUN apt update && apt install wget -y && apt install software-properties-common -y \
 && add-apt-repository ppa:deadsnakes/ppa -y \
  && apt install python3.12-full python3.12-dev python3.10-venv -y \
 && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1 \
 && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 2 \
 && update-alternatives --set python3 /usr/bin/python3.12 \
 && wget https://bootstrap.pypa.io/get-pip.py \
 && python3 get-pip.py

  # pip: avoid caching wheels
  RUN pip config set global.no-cache-dir true; \
  # remove transient files and apt caches
  rm -f get-pip.py; \
  apt-get purge -y --auto-remove wget software-properties-common; \
  rm -rf /var/lib/apt/lists/* /var/cache/apt/* /root/.cache

 
RUN echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/00-docker
RUN echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/00-docker
RUN DEBIAN_FRONTEND=noninteractive \
  apt-get update \
  && apt-get install -y python3 \
  && rm -rf /var/lib/apt/lists/*
RUN useradd -ms /bin/bash apprunner
USER apprunner
