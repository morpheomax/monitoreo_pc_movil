#!/bin/zsh
cd -- "${0:A:h}" || exit 1
if command -v python3 >/dev/null 2>&1; then
  python3 start.py "$@"
  monitor_status=$?
else
  echo "Instala Python 3.11 o posterior y vuelve a abrir este archivo."
  monitor_status=1
fi
read -r "?Pulsa Enter para cerrar."
exit "$monitor_status"
