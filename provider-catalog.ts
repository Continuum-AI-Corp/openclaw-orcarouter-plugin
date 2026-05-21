import type { ModelProviderConfig } from "openclaw/plugin-sdk/provider-model-shared";

export const ORCAROUTER_BASE_URL = "https://api.orcarouter.ai/v1";
export const ORCAROUTER_DEFAULT_MODEL_ID = "orcarouter/auto";

const ORCAROUTER_DEFAULT_CONTEXT_WINDOW = 200000;
const ORCAROUTER_DEFAULT_MAX_TOKENS = 8192;
const ZERO_COST = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };

function normalizeBaseUrl(baseUrl: string | undefined): string {
  return (baseUrl ?? "").trim().replace(/\/+$/, "");
}

export function normalizeOrcaRouterBaseUrl(baseUrl: string | undefined): string | undefined {
  const normalized = normalizeBaseUrl(baseUrl);
  if (!normalized) {
    return undefined;
  }
  if (
    normalized === ORCAROUTER_BASE_URL ||
    normalized === "https://orcarouter.ai/v1" ||
    normalized === "https://www.orcarouter.ai/v1"
  ) {
    return ORCAROUTER_BASE_URL;
  }
  return undefined;
}

export function buildOrcarouterProvider(): ModelProviderConfig {
  return {
    baseUrl: ORCAROUTER_BASE_URL,
    api: "openai-completions",
    models: [
      {
        id: ORCAROUTER_DEFAULT_MODEL_ID,
        name: "OrcaRouter Auto",
        reasoning: false,
        input: ["text", "image"],
        cost: ZERO_COST,
        contextWindow: ORCAROUTER_DEFAULT_CONTEXT_WINDOW,
        maxTokens: ORCAROUTER_DEFAULT_MAX_TOKENS,
      },
      {
        id: "openai/gpt-5.5",
        name: "OpenAI GPT-5.5",
        reasoning: true,
        input: ["text", "image"],
        cost: ZERO_COST,
        contextWindow: 400000,
        maxTokens: 16384,
      },
      {
        id: "anthropic/claude-opus-4.7",
        name: "Anthropic Claude Opus 4.7",
        reasoning: true,
        input: ["text", "image"],
        cost: ZERO_COST,
        contextWindow: 200000,
        maxTokens: 16384,
      },
      {
        id: "google/gemini-3-flash-preview",
        name: "Google Gemini 3 Flash Preview",
        reasoning: true,
        input: ["text", "image"],
        cost: ZERO_COST,
        contextWindow: 1048576,
        maxTokens: 32768,
      },
      {
        id: "deepseek/deepseek-v4-pro",
        name: "DeepSeek V4 Pro",
        reasoning: true,
        input: ["text"],
        cost: ZERO_COST,
        contextWindow: 128000,
        maxTokens: 16384,
      },
    ],
  };
}
