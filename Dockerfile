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
  RUN rm -f get-pip.py; \
  apt-get purge -y --auto-remove wget software-properties-common; \
  rm -rf /var/lib/apt/lists/* /var/cache/apt/* /root/.cache



# Clean, noninteractive install + aggressive cache cleanup (safe to keep all installed pkgs)
RUN set -eux; \
  echo 'tzdata tzdata/Areas select America' | debconf-set-selections; \
  echo 'tzdata tzdata/Zones/America select Los_Angeles' | debconf-set-selections; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    tzdata \
    software-properties-common netcat-openbsd kmod unzip openssh-server \
    curl wget lsof zsh ccache tmux htop git-lfs tree \
    build-essential cmake \
    libopenmpi-dev libnuma1 libnuma-dev \
    libibverbs-dev libibverbs1 libibumad3 \
    librdmacm1 libnl-3-200 libnl-route-3-200 libnl-route-3-dev libnl-3-dev \
    ibverbs-providers infiniband-diags perftest \
    libgoogle-glog-dev libgtest-dev libjsoncpp-dev libunwind-dev \
    libboost-all-dev libssl-dev \
    libgrpc-dev libgrpc++-dev libprotobuf-dev protobuf-compiler-grpc \
    pybind11-dev \
    libhiredis-dev libcurl4-openssl-dev \
    libczmq4 libczmq-dev \
    libfabric-dev \
    patchelf \
    nvidia-dkms-550 \
    devscripts debhelper fakeroot dkms check libsubunit0 libsubunit-dev; \
  ln -sf /usr/bin/python3.12 /usr/bin/python; \
  # ---- Cleanup: apt/lists, archives, metadata, tmp, and common caches ----
  apt-get clean; \
  rm -rf /var/lib/apt/lists/*; \
  rm -rf /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/* /var/cache/apt/*.bin; \
  rm -rf /var/cache/debconf/*-old; \
  rm -rf /var/log/apt/*; \
  rm -rf /tmp/* /var/tmp/*; \
  # If any tools created caches (pip, wget, etc.), clear them too:
  rm -rf /root/.cache

    # GDRCopy installation
RUN mkdir -p /tmp/gdrcopy && cd /tmp \
 && git clone https://github.com/NVIDIA/gdrcopy.git -b v2.4.4 \
 && cd gdrcopy/packages \
 && CUDA=/usr/local/cuda ./build-deb-packages.sh \
 && dpkg -i gdrdrv-dkms_*.deb libgdrapi_*.deb gdrcopy-tests_*.deb gdrcopy_*.deb \
 && cd / && rm -rf /tmp/gdrcopy; \
 apt-get clean; \
 rm -rf /var/lib/apt/lists/* /var/cache/apt/* /root/.cache; \
 rm -rf /var/cache/*  rm -rf /var/log/* ; \
 rm -rf /tmp/* /var/tmp/


 # Fix DeepEP IBGDA symlink
RUN ln -sf /usr/lib/x86_64-linux-gnu/libmlx5.so.1 /usr/lib/x86_64-linux-gnu/libmlx5.so

# Clone and install SGLang
WORKDIR /sgl-workspace
RUN python3 -m pip install --upgrade pip setuptools wheel html5lib six \
 && python3 -m pip cache purge ; \
 apt-get clean; \
 rm -rf /var/lib/apt/lists/* /var/cache/apt/* /root/.cache; \
 rm -rf /var/cache/*  rm -rf /var/log/* ; \
 rm -rf /tmp/* /var/tmp/
 
 RUN git clone --depth=1 https://github.com/sgl-project/sglang.git \
 && cd sglang \
 && case "$CUDA_VERSION" in \
      12.6.1) CUINDEX=126 ;; \
      12.8.1) CUINDEX=128 ;; \
      12.9.1) CUINDEX=129 ;; \
      *) echo "Unsupported CUDA version: $CUDA_VERSION" && exit 1 ;; \
    esac \
 && python3 -m pip install --no-cache-dir -e "python[${BUILD_TYPE}]" --extra-index-url https://download.pytorch.org/whl/cu${CUINDEX} \
 && python3 -m pip cache purge ; \
 apt-get clean; \
 rm -rf /var/lib/apt/lists/* /var/cache/apt/* /root/.cache; \
 rm -rf /var/cache/*  rm -rf /var/log/* ; \
 rm -rf /tmp/* /var/tmp/


 RUN python3 -m pip install --no-cache-dir nvidia-nccl-cu12==2.27.6 --force-reinstall --no-deps \
 && python3 -m pip cache purge ; \
 apt-get clean; \
 rm -rf /var/lib/apt/lists/* /var/cache/apt/* /root/.cache; \
 rm -rf /var/cache/*  rm -rf /var/log/* ; \
 rm -rf /tmp/* /var/tmp/






 
RUN echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/00-docker
RUN echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/00-docker
RUN DEBIAN_FRONTEND=noninteractive \
  apt-get update \
  && apt-get install -y python3 \
  && rm -rf /var/lib/apt/lists/*
RUN useradd -ms /bin/bash apprunner
USER apprunner
