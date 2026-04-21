# fzf-bindings.zsh — fuzzy-browse and optionally invoke any configured keybind.
#
# Binding: ^X^L  (mnemonic: eXtended / List-keybinds)
#
# Selecting a line with Enter invokes the associated widget against the
# current command line. Dismissing with Ctrl-C or Esc exits gracefully
# (fzf exit 130 → empty stdout → widget no-ops and redraws the prompt).
#
# Only invokes widgets that are registered with `zle -la`. Bindings that
# point to non-widget names (rare, usually historical) are flagged but
# not invoked.

fzf-bindkey-widget() {
  local line widget
  line=$(bindkey -L | fzf \
    --prompt='bindkey> ' \
    --height=60% \
    --reverse \
    --tiebreak=begin \
    --header=$'Enter: invoke bound widget on current line\nCtrl-C/Esc: dismiss')

  if [[ -z "$line" ]]; then
    zle redisplay
    return 0
  fi

  # bindkey output format: `bindkey "<seq>" <widget-name>`
  # Widget is the last whitespace-separated token; may be single-quoted.
  widget="${line##* }"
  widget="${widget//\'/}"
  widget="${widget//\"/}"

  if zle -la "$widget" >/dev/null 2>&1; then
    zle "$widget"
  else
    zle -M "fzf-bindkey: '$widget' is not a registered widget; nothing to invoke"
  fi
  zle redisplay
}
zle -N fzf-bindkey-widget
bindkey '^X^L' fzf-bindkey-widget
