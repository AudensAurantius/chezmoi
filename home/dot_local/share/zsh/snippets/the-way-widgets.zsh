# the-way-widgets.zsh — zsh integration for the-way snippet manager.
#
# Bindings:
#   ^X^S   Save current $BUFFER as a new the-way snippet
#          (the-way prompts for description/tags interactively after
#          the terminal swap; control returns to zle on exit)
#   ^X^P   fzf-pick a snippet and append its code into $BUFFER
#   ^X^R   Fuzzy-pick a line from shell history and save it as a
#          the-way snippet (same interactive metadata flow as ^X^S)
#
# Ctrl-C / Esc in any fzf picker exits gracefully (fzf exit 130 →
# empty selection → widget no-ops and redraws the prompt).

# ---- ^X^S : save $BUFFER ------------------------------------------------
the-way-save-buffer-widget() {
  if [[ -z "$BUFFER" ]]; then
    zle -M "the-way: buffer is empty; nothing to save"
    return 0
  fi
  if ! command -v the-way >/dev/null 2>&1; then
    zle -M "the-way: binary not on PATH"
    return 0
  fi
  # the-way cmd <code> adds a shell snippet and prompts for metadata.
  # zle yields the TTY automatically; reset-prompt after re-entry.
  the-way cmd "$BUFFER"
  zle reset-prompt
}
zle -N the-way-save-buffer-widget
bindkey '^X^S' the-way-save-buffer-widget

# ---- ^X^P : pick snippet and append to $BUFFER --------------------------
the-way-pick-widget() {
  if ! command -v the-way >/dev/null 2>&1; then
    zle -M "the-way: binary not on PATH"
    return 0
  fi
  # `the-way cp --stdout` opens the-way's native fuzzy picker when no
  # INDEX is given, then prints the selected snippet's code to stdout
  # instead of copying to clipboard. Ctrl-C inside the picker → empty
  # stdout → graceful no-op.
  local selected
  selected=$(the-way cp --stdout 2>/dev/null)
  if [[ -z "$selected" ]]; then
    zle redisplay
    return 0
  fi
  LBUFFER+="$selected"
  zle redisplay
}
zle -N the-way-pick-widget
bindkey '^X^P' the-way-pick-widget

# ---- ^X^R : fzf over history, save selection as snippet -----------------
the-way-save-from-history-widget() {
  if ! command -v the-way >/dev/null 2>&1; then
    zle -M "the-way: binary not on PATH"
    return 0
  fi
  local line
  # fc -l -n 1  : list full history without numbers, oldest first
  # awk de-dupe : collapse repeated commands (typical fzf-history idiom)
  # --tac       : show newest first in the picker
  line=$(fc -l -n 1 | awk '!seen[$0]++' | fzf \
    --prompt='the-way save> ' \
    --height=40% \
    --reverse \
    --tac \
    --no-sort \
    --header=$'Enter: save selected history line as the-way snippet\nCtrl-C/Esc: dismiss')
  if [[ -z "$line" ]]; then
    zle redisplay
    return 0
  fi
  the-way cmd "$line"
  zle reset-prompt
}
zle -N the-way-save-from-history-widget
bindkey '^X^R' the-way-save-from-history-widget
