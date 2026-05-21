import type { StreamFn } from "@earendil-works/pi-agent-core";
import {
  type ProviderResolveDynamicModelContext,
  type ProviderRuntimeModel,
  type ProviderWrapStreamFnContext,
} from "openclaw/plugin-sdk/plugin-entry";
import { DEFAULT_CONTEXT_TOKENS } from "openclaw/plugin-sdk/provider-model-shared";
import { defineSingleProviderPluginEntry } from "openclaw/plugin-sdk/provider-entry";
import { applyOrcarouterConfig, ORCAROUTER_DEFAULT_MODEL_REF } from "./onboard.js";
import {
  buildOrcarouterProvider,
  normalizeOrcaRouterBaseUrl,
  ORCAROUTER_BASE_URL,
} from "./provider-catalog.js";

const PROVIDER_ID = "orcarouter";
const ORCAROUTER_DEFAULT_MAX_TOKENS = 8192;

// OrcaRouter attribution headers per cross-project notes §12.
// Documented contract: OpenAI-compatible router accepts unknown headers; included
// so the OrcaRouter console can attribute traffic to OpenClaw.
const ORCAROUTER_ATTRIBUTION_HEADERS: Record<string, string> = {
  "HTTP-Referer": "https://openclaw.ai",
  "X-Title": "OpenClaw",
};

function isVerifiedOrcaRouterRoute(model: Parameters<StreamFn>[0]): boolean {
  const provider = typeof model.provider === "string" ? model.provider.trim().toLowerCase() : "";
  const baseUrl = typeof model.baseUrl === "string" ? model.baseUrl : undefined;
  if (baseUrl) {
    return normalizeOrcaRouterBaseUrl(baseUrl) === ORCAROUTER_BASE_URL;
  }
  return provider === PROVIDER_ID;
}

function createOrcaRouterAttributionWrapper(baseStreamFn: StreamFn | undefined): StreamFn {
  return (model, context, options) => {
    if (!baseStreamFn) {
      throw new Error(`OrcaRouter wrapper requires an underlying streamFn for ${model.id}.`);
    }
    if (!isVerifiedOrcaRouterRoute(model)) {
      return baseStreamFn(model, context, options);
    }
    return baseStreamFn(model, context, {
      ...options,
      headers: {
        ...ORCAROUTER_ATTRIBUTION_HEADERS,
        ...options?.headers,
      },
    });
  };
}

function buildDynamicOrcaRouterModel(
  ctx: ProviderResolveDynamicModelContext,
): ProviderRuntimeModel {
  // Free-form: any string after the orcarouter/ prefix is forwarded to OrcaRouter.
  // Capabilities default to broad text+image because OrcaRouter routes to many vendors.
  return {
    id: ctx.modelId,
    name: ctx.modelId,
    api: "openai-completions",
    provider: PROVIDER_ID,
    baseUrl: ORCAROUTER_BASE_URL,
    reasoning: false,
    input: ["text", "image"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: DEFAULT_CONTEXT_TOKENS,
    maxTokens: ORCAROUTER_DEFAULT_MAX_TOKENS,
  };
}

export default defineSingleProviderPluginEntry({
  id: PROVIDER_ID,
  name: "OrcaRouter Provider",
  description: "OrcaRouter — adaptive routing across many LLMs through a single OpenAI-compatible API.",
  provider: {
    label: "OrcaRouter",
    docsPath: "/providers/orcarouter",
    envVars: ["ORCAROUTER_API_KEY"],
    auth: [
      {
        methodId: "api-key",
        label: "OrcaRouter API key",
        hint: "API key (starts with sk-orca-)",
        optionKey: "orcarouterApiKey",
        flagName: "--orcarouter-api-key",
        envVar: "ORCAROUTER_API_KEY",
        promptMessage: "Enter OrcaRouter API key",
        defaultModel: ORCAROUTER_DEFAULT_MODEL_REF,
        applyConfig: (cfg) => applyOrcarouterConfig(cfg),
        wizard: {
          choiceId: "orcarouter-api-key",
          choiceLabel: "OrcaRouter API key",
          groupId: "orcarouter",
          groupLabel: "OrcaRouter",
          groupHint: "API key",
          onboardingScopes: ["text-inference"],
        },
      },
    ],
    catalog: {
      buildProvider: () => buildOrcarouterProvider(),
      buildStaticProvider: () => buildOrcarouterProvider(),
    },
    resolveDynamicModel: (ctx) => buildDynamicOrcaRouterModel(ctx),
    normalizeConfig: ({ providerConfig }) => {
      const normalizedBaseUrl = normalizeOrcaRouterBaseUrl(providerConfig.baseUrl);
      return normalizedBaseUrl && normalizedBaseUrl !== providerConfig.baseUrl
        ? { ...providerConfig, baseUrl: normalizedBaseUrl }
        : undefined;
    },
    isModernModelRef: () => true,
    wrapStreamFn: (ctx: ProviderWrapStreamFnContext) =>
      createOrcaRouterAttributionWrapper(ctx.streamFn),
  },
});
