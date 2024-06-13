src=~/.local/src/fzf-tab-completion/bash/fzf-bash-completion.sh
if [ -e "$src" ]; then
	source "$src"
	bind -x '"\t": fzf_bash_completion'
fi
