case $- in
  *i*) ;;
  *) return ;;
esac

if command -v update-ai-clis >/dev/null 2>&1; then
  ai_cli_stamp=${XDG_STATE_HOME:-$HOME/.local/state}/ai-cli-updates/last-success
  ai_cli_lock=${XDG_STATE_HOME:-$HOME/.local/state}/ai-cli-updates/lock
  mkdir -p "$(dirname "$ai_cli_stamp")"

  if [ ! -e "$ai_cli_stamp" ] || find "$ai_cli_stamp" -mtime +0 >/dev/null 2>&1; then
    (
      if mkdir "$ai_cli_lock" 2>/dev/null; then
        trap 'rmdir "$ai_cli_lock"' EXIT
        if update-ai-clis >/tmp/update-ai-clis.log 2>&1; then
          touch "$ai_cli_stamp"
        fi
      fi
    ) >/dev/null 2>&1 &
  fi
fi

# Ensure the shared Claude config (CLAUDE_CONFIG_DIR) is present. The image has
# no ssh, so clone over HTTPS (works when the repo is public). Best-effort and
# attempted at most once per container, so it never blocks or spams the shell.
if [ -n "${CLAUDE_CONFIG_DIR:-}" ] && [ ! -e "$CLAUDE_CONFIG_DIR/.git" ] \
   && [ ! -e /tmp/.my-dot-claude-clone-tried ] && command -v git >/dev/null 2>&1; then
  : > /tmp/.my-dot-claude-clone-tried
  if git clone https://github.com/JeffreyBenjaminBrown/my-dot-claude.git \
        "$CLAUDE_CONFIG_DIR" >/tmp/my-dot-claude-clone.log 2>&1; then
    echo "[init] cloned shared Claude config into $CLAUDE_CONFIG_DIR"
  else
    echo "[init] NOTE: couldn't clone my-dot-claude into $CLAUDE_CONFIG_DIR" \
         "(private repo or offline?); see /tmp/my-dot-claude-clone.log"
  fi
fi

PS1='\w [\D{%F %T}]\n\$ '
