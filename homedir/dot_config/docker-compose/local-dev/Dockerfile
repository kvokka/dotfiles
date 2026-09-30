FROM ubuntu:26.04

ARG TZ=Asia/Bangkok
ENV TZ=${TZ}

# hadolint ignore=DL3008 # apt versions are pinned by the ubuntu:24.04 base, not here
RUN apt update \
  && apt install -y --no-install-recommends \
  binutils \
  build-essential \
  ca-certificates \
  software-properties-common \
  curl \
  locales \
  sudo \
  tini \
  tzdata \
  zsh \
  && add-apt-repository ppa:git-core/ppa -y \
  && ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime \
  && echo "$TZ" > /etc/timezone \
  && dpkg-reconfigure -f noninteractive tzdata \
  && echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ubuntu \
  && chmod 0440 /etc/sudoers.d/ubuntu \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

USER ubuntu
WORKDIR /home/ubuntu/proj/active

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
