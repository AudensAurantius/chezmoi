#compdef readable
###-begin-readable-completions-###
#
# yargs command completion script
#
# Installation: /home/hactar/.npm-packages/bin/readable --completion >> ~/.zshrc
#    or /home/hactar/.npm-packages/bin/readable --completion >> ~/.zsh_profile on OSX.
#
_readable_yargs_completions()
{
  local reply
  local si=$IFS
  IFS=$'
' reply=($(COMP_CWORD="$((CURRENT-1))" COMP_LINE="$BUFFER" COMP_POINT="$CURSOR" /home/hactar/.npm-packages/bin/readable --get-yargs-completions "${words[@]}"))
  IFS=$si
  _describe 'values' reply
}
compdef _readable_yargs_completions readable
###-end-readable-completions-###

