FROM ubuntu:24.04

ARG DOTFILES_GITHUB_USERNAME=kvokka
ENV DOTFILES_GITHUB_USERNAME=${DOTFILES_GITHUB_USERNAME}

ARG TZ=Asia/Bangkok
ENV TZ=${TZ}

# hadolint ignore=DL3004
RUN apt-get install -y --no-install-recommends sudo tini zsh curl git locales build-essential tzdata \
  && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
  && echo $TZ > /etc/timezone \
  && dpkg-reconfigure -f noninteractive tzdata \  && echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ubuntu \
  && chmod 0440 /etc/sudoers.d/ubuntu \
  && sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
  && locale-gen en_US.UTF-8 \
  && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# shared deps
RUN apt-get update && apt-get install -y \
  # set up libasound2t64 for agent-browser as a spike for linux
  libasound2t64 \
  # required for jpackage
  binutils \
  fakeroot \
  libc6 \
  imagemagick \
  gcc

ENV LANG=en_US.UTF-8 \
  LC_ALL=en_US.UTF-8 \
  LANGUAGE=en_US.UTF-8 \
  SHELL=zsh \
  WORKDIR=/home/ubuntu/proj/active \
  RUNNING_IN_DOCKER=true

WORKDIR /home/ubuntu/proj/active
USER ubuntu

ENV PATH=$PATH:/opt/wise-gen/bin

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
