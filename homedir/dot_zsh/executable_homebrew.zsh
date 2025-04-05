# Homebrew environment setup
if (( $+commands[brew] )); then
  BREW_PREFIX=$(brew --prefix)
  if [[ -z "$CPPFLAGS" || "$CPPFLAGS" != *"${BREW_PREFIX}/include"* ]]; then
    export CPPFLAGS="${CPPFLAGS:+$CPPFLAGS }-I${BREW_PREFIX}/include"
  fi
  if [[ -z "$LDFLAGS" || "$LDFLAGS" != *"${BREW_PREFIX}/lib"* ]]; then
    export LDFLAGS="${LDFLAGS:+$LDFLAGS }-L${BREW_PREFIX}/lib"
  fi
  if [[ -z "$PKG_CONFIG_PATH" || "$PKG_CONFIG_PATH" != *"${BREW_PREFIX}/lib/pkgconfig"* ]]; then
    export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:+$PKG_CONFIG_PATH:}${BREW_PREFIX}/lib/pkgconfig"
  fi
  if [[ -d "${BREW_PREFIX}/bin" && "$PATH" != *"${BREW_PREFIX}/bin"* ]]; then
    export PATH="${BREW_PREFIX}/bin:$PATH"
  fi
fi
