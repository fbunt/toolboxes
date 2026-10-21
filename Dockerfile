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
    conda update --yes --quiet ca-certificates certifi > /dev/null && \
    conda clean --tarballs --index-cache --packages --yes && \
    find ${CONDA_DIR} -follow -type f -name '*.a' -delete && \
    find ${CONDA_DIR} -follow -type f -name '*.pyc' -delete && \
    conda clean --force-pkgs-dirs --all --yes  && \
    echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
    echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc

# Add tools
RUN dnf -y copr enable atim/starship > /dev/null && \
    dnf -y install --setopt=install_weak_deps=False \
        ImageMagick \
        automake \
        clang \
        clang-tools-extra \
        cmake \
        fd-find \
        ffmpeg \
        fuse \
        fuse-libs \
        gcc \
        gcc-c++ \
        gh \
        git \
        htop \
        jq \
        kernel-devel \
        keychain \
        make \
        ncdu \
        neovim \
        nodejs-npm \
        openssh-server \
        parallel \
        pv \
        ripgrep \
        rsync \
        screen \
        starship \
        stow \
        tini \
        tree-sitter-cli \
        vim \
        wget \
        wl-clipboard \
        xclip \
        zoxide \
        zstd \
        > /dev/null && \
    dnf clean all
# And zellij
RUN wget --no-hsts --quiet https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz -O /tmp/zellij.tar.gz && \
    tar -xf /tmp/zellij.tar.gz -C /usr/local/bin && \
    chmod +x /usr/local/bin/zellij && \
    rm /tmp/zellij.tar.gz
# Add uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
# Add pixi
COPY --from=ghcr.io/prefix-dev/pixi:latest /usr/local/bin/pixi /bin/
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

# Enable host podman
RUN ln -s /usr/bin/distrobox-host-exec /usr/local/bin/podman

# Distrust emSign ECC Root CA - G3 (eMudhra intermediate key compromise) until
# Fedora's ca-certificates drops it. Conda, uv, pixi and Node ship their own
# root bundles, so point them at the system bundle, which honours the blocklist.
RUN trust extract --format=pem-bundle \
        --filter='pkcs11:id=%7C%5D%02%84%13%D4%CC%8A%9B%81%CE%17%1C%2E%29%1E%9C%48%63%42;type=cert' \
        /etc/pki/ca-trust/source/blocklist/emsign-ecc-g3.pem && \
    { [ -s /etc/pki/ca-trust/source/blocklist/emsign-ecc-g3.pem ] || \
        echo "emSign ECC Root CA - G3 is no longer shipped; this block can be removed"; } && \
    update-ca-trust
ENV SSL_CERT_FILE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
    NODE_OPTIONS=--use-openssl-ca

ENTRYPOINT ["tini", "--"]
CMD [ "/bin/bash" ]
