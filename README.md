# @orcarouter/openclaw-provider

OrcaRouter provider plugin for [OpenClaw](https://github.com/openclaw/openclaw) — adaptive routing across many LLMs through a single OpenAI-compatible API (`https://api.orcarouter.ai/v1`).

> I'm an engineer on the OrcaRouter team.

## Install

Requires OpenClaw `2026.5.17` or newer (Node ≥ 22).

```bash
openclaw plugins install clawhub:@orcarouter/openclaw-provider
# or, during launch cutover, from npm directly:
openclaw plugins install @orcarouter/openclaw-provider
```

## Configure

```bash
openclaw onboard --auth-choice orcarouter-api-key
# or:
openclaw onboard --orcarouter-api-key "$ORCAROUTER_API_KEY"
```

OrcaRouter API keys start with `sk-orca-`. Get one at [orcarouter.ai/console](https://www.orcarouter.ai/console).

Config snippet (`~/.openclaw/config.json5`):

```json5
{
  env: { ORCAROUTER_API_KEY: "sk-orca-..." },
  agents: {
    defaults: {
      model: { primary: "orcarouter/auto" },
    },
  },
}
```

## Models

Model refs follow `orcarouter/<vendor>/<model>` for routed upstream models, plus the virtual router `orcarouter/auto`.

| Model ref                          | Notes                                                                          |
| ---------------------------------- | ------------------------------------------------------------------------------ |
| `orcarouter/auto`                  | Adaptive router; strategy is configurable per workspace at orcarouter.ai/console |
| `openai/gpt-5.5`                   | OpenAI flagship                                                                |
| `anthropic/claude-opus-4.7`        | Anthropic reasoning flagship (does **not** accept `temperature`)               |
| `google/gemini-3-flash-preview`    | Google preview                                                                 |
| `deepseek/deepseek-v4-pro`         | DeepSeek flagship                                                              |

Free-form model strings are accepted — any `orcarouter/<vendor>/<model>` ID is forwarded as-is. See the full catalog at [orcarouter.ai/models](https://www.orcarouter.ai/models).

## Routing

`orcarouter/auto` is a virtual router, not a model. Strategy options configured at [orcarouter.ai/console/routing](https://www.orcarouter.ai/console/routing):

| Strategy          | Behavior                                                                     |
| ----------------- | ---------------------------------------------------------------------------- |
| `cheapest`        | Lowest-priced upstream that can serve the request (default).                 |
| `balanced`        | Trades off price vs latency vs quality.                                      |
| `quality`         | Highest-quality upstream.                                                    |
| `adaptive`        | LinUCB contextual bandit picks among candidates from request features.       |
| `gated_adaptive`  | Adaptive plus a task-difficulty score that gates between weak/strong pools.  |

`extra_body` (per-request routing override):

```json
{ "extra_body": { "models": ["openai/gpt-5", "openai/gpt-4o"], "route": "fallback" } }
```

## Attribution headers

On verified `api.orcarouter.ai` routes, the plugin sends:

| Header          | Value                  |
| --------------- | ---------------------- |
| `HTTP-Referer`  | `https://openclaw.ai`  |
| `X-Title`       | `OpenClaw`             |

OrcaRouter accepts unknown headers (OpenAI-compat); attribution surfaces in the OrcaRouter console traffic view.

## Caveats

- `orcarouter/auto` defaults to the `cheapest` strategy, which may select upstreams without tool/function-calling support. For agentic flows that require tool calls, either pin a tool-capable model (e.g. `orcarouter/openai/gpt-5`) or adjust the `auto` router pool at [orcarouter.ai/console/routing](https://www.orcarouter.ai/console/routing).
- Reasoning models reject `temperature`:
  - `anthropic/claude-opus-4.7`
  - OpenAI `gpt-5` family (incl. `mini`/`nano`)
  - `deepseek/deepseek-reasoner`
  Pass reasoning controls via `reasoning_effort` (top-level) for OpenAI / Gemini / Grok / Qwen / Kimi reasoners; via `thinking: {type: "enabled", budget_tokens: N}` for Anthropic.

## Development

```bash
npm install
npm run test           # unit tests
LIVE=1 OPENCLAW_LIVE_TEST=1 ORCAROUTER_API_KEY=sk-orca-... npm run test:live
```

## License

MIT
