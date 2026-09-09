<!-- What situation does this change? Lead with that, the way a CHANGELOG entry does. -->

Closes #

## Preflight

```bash
python3 script/check.py
python3 script/adapter-smoke.py
bash script/tests/push-guard.sh
bash script/tests/notify-update.sh
bash script/tests/session-start.sh
```

- [ ] The five above are green locally
- [ ] `version` in `plugins/flow/.claude-plugin/plugin.json` and the newest `CHANGELOG.md` heading match
- [ ] Adapters regenerated with `python3 script/adapter-build.py`, not edited by hand
- [ ] A hook change ships with its test under `script/tests/`
