# Bolan shell integration for Bash.
# Implements OSC 133 (semantic prompt markers) for the block model.

__bolan_prompt_start() { printf '\e]133;A\a'; }
__bolan_prompt_end()   { printf '\e]133;B\a'; }
__bolan_cmd_start()    { printf '\e]133;C\a'; }
__bolan_cmd_end()      { printf "\e]133;D;$?\a"; }

__bolan_preexec() {
    __bolan_prompt_end
    __bolan_cmd_start
}

__bolan_precmd() {
    __bolan_cmd_end
    __bolan_prompt_start
}

# Install hooks via PROMPT_COMMAND
if [[ -z "$__bolan_installed" ]]; then
    trap '__bolan_preexec' DEBUG
    PROMPT_COMMAND="__bolan_precmd;${PROMPT_COMMAND}"
    __bolan_installed=1
fi
