# Bolan shell integration — auto-sourced by Bolan terminal sessions.
# Implements OSC 133 (semantic prompt markers) for the block model.

__bolan_prompt_start() { printf '\e]133;A\a'; }
__bolan_prompt_end()   { printf '\e]133;B\a'; }
__bolan_cmd_start()    { printf '\e]133;C\a'; }
__bolan_cmd_end()      { printf "\e]133;D;$?\a"; }

add-zsh-hook precmd  __bolan_prompt_start
add-zsh-hook precmd  __bolan_cmd_end
add-zsh-hook preexec __bolan_prompt_end
add-zsh-hook preexec __bolan_cmd_start
