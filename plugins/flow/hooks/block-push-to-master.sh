#!/usr/bin/env bash
# Hook PreToolUse (matcher: Bash). Bloquea git push peligrosos hacia master/main.
# Recibe el evento JSON por stdin; exit 2 aborta la herramienta y devuelve el motivo al agente.

cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null || true)

# Solo nos interesa si el comando contiene un 'git push' (cubre 'rtk git push', 'rtk proxy git push', etc.)
echo "$cmd" | grep -qE 'git[[:space:]]+push' || exit 0

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# 1) Estás parado en master/main
if [ "$branch" = "master" ] || [ "$branch" = "main" ]; then
  echo "BLOQUEADO: push desde '$branch'. No se empuja desde la rama principal. Cámbiate a una rama de trabajo (git switch -c PROJ-XXXXX-slug --no-track origin/master)." >&2
  exit 2
fi

# 2) master/main aparece como token suelto (HEAD:master, origin master, refs/heads/master, master:master…)
#    Ya sabemos que hay un 'git push' en el comando, así que un token 'master'/'main' suelto es peligroso.
if echo "$cmd" | grep -qE '(^|[[:space:]]|:|/)(master|main)([[:space:]]|:|$)'; then
  echo "BLOQUEADO: el push referencia master/main. Empuja a tu rama: 'git push -u origin HEAD'." >&2
  exit 2
fi

# 3) Push a ciegas ('git push' / 'git push origin') con el upstream apuntando a master/main
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "")
if { [ "$upstream" = "origin/master" ] || [ "$upstream" = "origin/main" ]; } \
   && echo "$cmd" | grep -qE 'git[[:space:]]+push([[:space:]]+origin)?[[:space:]]*$'; then
  echo "BLOQUEADO: upstream='$upstream'; un push a ciegas iría a $upstream. Corrige con 'git branch --unset-upstream' y usa 'git push -u origin HEAD'." >&2
  exit 2
fi

exit 0
