# Introduction

This are my .env files

# Quick start

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/kvokka/dotfiles/HEAD/.config/yadm/install)"
```

# How to fork & re-use

1. Clone

```bash
git clone git@github.com:kvokka/dotfiles.git
```

2. Remove extras

```bash
rm -fr dotfiles/.local
rm -fr dotfiles.toad
rm dotfiles/.travis/config.yml
```

3. Patch these files with your data using

```bash
grep -Ril 'kvokka' .
```

4. Set correct path to your repo

```bash
git remote set-url origin git@github.com:my-github-user/dotfiles.git
```
