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

PS1='\w [\D{%F %T}]\n\$ '
