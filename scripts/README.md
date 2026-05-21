# Local test scripts

Three-stage test ladder for the OrcaRouter OpenClaw plugin. Stage 1 is offline; stages 2 and 3 need a real `sk-orca-` key.

## Setup (one-time)

```powershell
# 1. Copy the env template and fill in your real key
Copy-Item .env.local.example .env.local
notepad .env.local        # paste sk-orca-xxx into ORCAROUTER_API_KEY=
```

`.env.local` is gitignored — your key never leaves your machine.

```powershell
# 2. Install plugin deps (one-time)
npm install --ignore-scripts
```

(`--ignore-scripts` is needed because the upstream `openclaw` npm package has a Windows-unfriendly `preinstall` hook.)

## Run

### Stage 1 — offline (typecheck + 8 unit tests, no key needed)

```powershell
powershell -File scripts\test-unit.ps1
```

### Stage 2 — live API (3 vitest tests against api.orcarouter.ai)

```powershell
powershell -File scripts\test-live.ps1
```

What it covers:
- `resolveDynamicModel("orcarouter/auto")` returns the right base URL + api
- Real chat completion through `api.orcarouter.ai/v1/chat/completions`
- A deliberately-wrong key returns HTTP 401 (not silent / not 500)

### Stage 3 — real-user end-to-end

Two flavors. Pick whichever your environment supports.

**3a — via globally installed `openclaw` CLI** (preferred):

```powershell
.\scripts\setup-prereqs.ps1            # one-time: installs openclaw@2026.5.12 globally
.\scripts\test-e2e.ps1
```

If `setup-prereqs.ps1` fails to install globally (Windows EPERM / corporate proxy / etc.), skip it and use 3b instead.

What it does:
1. `npm pack` → `orcarouter-openclaw-provider-0.1.0.tgz`
2. `openclaw plugins install <tgz>` into an isolated `.openclaw-test-home/`
3. `openclaw onboard --orcarouter-api-key sk-orca-...`
4. Runs `openclaw agent` against 3 scenarios:
   - `orcarouter/auto` — adaptive routing
   - `orcarouter/anthropic/claude-opus-4.7` — pinned reasoning model
   - Chinese prompt — i18n smoke test

**3b — via the upstream clone at `E:\tmp\openclaw-upstream`** (fallback, if your global CLI is too old):

```powershell
# One-time: install upstream deps (~5min)
cd E:\tmp\openclaw-upstream
pnpm install

# Then back here:
cd E:\python-project\openclaw-orcarouter-plugin
powershell -File scripts\test-e2e-from-source.ps1
```

This copies our plugin into `extensions/orcarouter/`, re-runs `pnpm install` + `pnpm build` in upstream, and runs `pnpm openclaw agent` against the same 3 scenarios.

### All stages

```powershell
powershell -File scripts\test-all.ps1
```

## What to report back

After each stage, copy-paste the terminal output (especially any **FAIL** / **WARN** lines). I'll diagnose and fix.

**Stage 2 things to watch for**:
- `expected /^OK[.!]?$/, received "..."` — model returned more than 'OK', usually safe to ignore; the test asserts strict match
- Timeout — auto router may be slow; pin a specific model via `OPENCLAW_LIVE_ORCAROUTER_MODEL` in `.env.local`
- `Function calling is not enabled` — the auto router picked a non-tool model (shared-notes §4 caveat); pin a tool-capable model

**Stage 3 things to watch for**:
- `openclaw plugins install` rejects the tarball — fall back to `test-e2e-from-source.ps1`
- `pnpm build` fails — read `E:\tmp\openclaw-upstream\AGENTS.md` §Build
- Agent returns empty response — onboard probably didn't write the API key; check `.openclaw-test-home/` contents

## Cleanup

```powershell
Remove-Item -Recurse -Force .openclaw-test-home, node_modules, orcarouter-openclaw-provider-*.tgz
```
