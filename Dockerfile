FROM ghcr.io/ublue-os/fedora-toolbox:latest

ENV MINIFORGE_VERSION=25.9.1-0
ENV ZELLIJ_VERSION=0.43.1
ENV CONDA_DIR=/opt/conda
ENV PATH=${CONDA_DIR}/bin:${PATH}

# Install and setup miniforge
RUN dnf -y upgrade > /dev/null && \
    dnf -y install --setopt=install_weak_deps=False \
        wget \
        bzip2 \
        ca-certificates \
        git \
        tini \
        > /dev/null && \
    dnf clean all && \
    wget --no-hsts --quiet https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-$(uname -m).sh -O /tmp/miniforge.sh && \
    /bin/bash /tmp/miniforge.sh -b -p ${CONDA_DIR} && \
    rm /tmp/miniforge.sh && \
    conda clean --tarballs --index-cache --packages --yes && \
    find ${CONDA_DIR} -follow -type f -name '*.a' -delete && \
    find ${CONDA_DIR} -follow -type f -name '*.pyc' -delete && \
    conda clean --force-pkgs-dirs --all --yes  && \
    echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
    echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc

# Add tools
RUN dnf -y copr enable atim/starship > /dev/null && \
    dnf -y install --setopt=install_weak_deps=False \
        automake \
        clang \
        clang-tools-extra \
        cmake \
        fd-find \
        gcc \
        gcc-c++ \
        git \
        htop \
        kernel-devel \
        keychain \
        make \
        ncdu \
        neovim \
        openssh-server \
        parallel \
        pv \
        ripgrep \
        rsync \
        screen \
        starship \
        stow \
        tini \
        vim \
        wget \
        zoxide \
        zstd \
        > /dev/null && \
    dnf clean all
# And zellij
RUN wget --no-hsts --quiet https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz -O /tmp/zellij.tar.gz && \
    tar -xf /tmp/zellij.tar.gz -C /usr/local/bin && \
    chmod +x /usr/local/bin/zellij && \
    rm /tmp/zellij.tar.gz
# Add rust/cargo and selene/stylua. Need to install once the $USER exists to get proper permissions
RUN cat > /etc/profile.d/rust.sh <<'EOF'
#!/bin/bash
# Check if current user is NOT root
if [ "$EUID" -ne 0 ]; then
    # Check if cargo is NOT installed
    if [ ! -f "${HOME}/.cargo/bin/cargo" ]; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --no-modify-path -y && \
            . ${HOME}/.cargo/env && \
            cargo install selene stylua
    else
        . ${HOME}/.cargo/env
    fi
fi
EOF

ENTRYPOINT ["tini", "--"]
CMD [ "/bin/bash" ]
