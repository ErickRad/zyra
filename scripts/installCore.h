#!/bin/bash
set -e

apt update

apt install -y \
  git \
  curl \
  wget \
  ca-certificates \
  sudo \
  build-essential \
  zsh \
  neovim \
  tmux
