# Working on the LINE offline installer

Read the [README](README.md) for the supported system and the [installation skill](.agents/skills/line-offline-install/SKILL.md) for the steps from a fresh checkout through sign-in. The skill is plain Markdown and can be read directly by an agent without skill support. Consult its [rebuild guide](.agents/skills/line-offline-install/references/rebuild.md) for input paths, versions and tests.

- Use [the pinned inventory](offline/phase1/inventory.json) and checked-in checksums to identify the original input files. Preserve the LINE executable and the upstream Wine runner. Keep Wine compatibility changes as source patches in `patches/` and build a separate runner.
- For a fresh installer build, generate the Wine runtime with `offline/phase2/build-runtime.sh`, build the LINE payload with `offline/phase3/build-payload.py`, then package the `.run` with `offline/phase5/build.sh`. Use the [clean Debian test](offline/phase5/verify.sh) to verify offline installation and `🔮🔥🙏` rendering. Confirm sign-in only after the account owner approves it and the chat list opens.
- Keep downloaded assets, generated installer executables, Wine prefixes, and account data local. Commit the source, documentation, checksums and test evidence from clean sessions. REA is optional for investigating new compatibility issues.
