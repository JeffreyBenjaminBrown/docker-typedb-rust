case $- in
  *i*) ;;
  *) return ;;
esac

# Keep Claude Code and Codex current. update-ai-clis does nothing if an update
# already succeeded today, serializes itself with a lock, and never replaces a
# working install with a broken one, so starting it from every shell is safe.
if command -v update-ai-clis >/dev/null 2>&1; then
  ( update-ai-clis >>/tmp/update-ai-clis.log 2>&1 & )
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
