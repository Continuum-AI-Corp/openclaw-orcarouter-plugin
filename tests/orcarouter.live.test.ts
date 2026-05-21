// Live test against api.orcarouter.ai. Skipped unless both env vars are set:
//
//   ORCAROUTER_API_KEY=sk-orca-xxx
//   OPENCLAW_LIVE_TEST=1
//
// Mirrors extensions/openrouter/openrouter.live.test.ts in openclaw upstream.

import { AuthStorage, ModelRegistry } from "@earendil-works/pi-coding-agent";
import OpenAI from "openai";
import {
  registerProviderPlugin,
  requireRegisteredProvider,
} from "openclaw/plugin-sdk/plugin-test-runtime";
import { describe, expect, it } from "vitest";
import plugin from "../index.js";
import { ORCAROUTER_BASE_URL } from "../provider-catalog.js";

const ORCAROUTER_API_KEY = process.env.ORCAROUTER_API_KEY ?? "";
const LIVE_MODEL_ID =
  process.env.OPENCLAW_LIVE_ORCAROUTER_MODEL?.trim() || "orcarouter/auto";
const liveEnabled =
  ORCAROUTER_API_KEY.trim().length > 0 && process.env.OPENCLAW_LIVE_TEST === "1";
const describeLive = liveEnabled ? describe : describe.skip;
const ModelRegistryCtor = ModelRegistry as unknown as {
  new (authStorage: AuthStorage, modelsJsonPath?: string): ModelRegistry;
};

const registerOrcaRouterPlugin = async () =>
  registerProviderPlugin({
    plugin,
    id: "orcarouter",
    name: "OrcaRouter Provider",
  });

describeLive("orcarouter plugin live", () => {
  it("registers an OrcaRouter provider and resolves the model dynamically", async () => {
    const { providers } = await registerOrcaRouterPlugin();
    const provider = requireRegisteredProvider(providers, "orcarouter");

    const resolved = provider.resolveDynamicModel?.({
      provider: "orcarouter",
      modelId: LIVE_MODEL_ID,
      modelRegistry: new ModelRegistryCtor(AuthStorage.inMemory()),
    });
    if (!resolved) {
      throw new Error(`orcarouter provider did not resolve ${LIVE_MODEL_ID}`);
    }

    expect(resolved.provider).toBe("orcarouter");
    expect(resolved.id).toBe(LIVE_MODEL_ID);
    expect(resolved.api).toBe("openai-completions");
    expect(resolved.baseUrl).toBe(ORCAROUTER_BASE_URL);
  });

  it("completes a real chat request through api.orcarouter.ai", async () => {
    const client = new OpenAI({
      apiKey: ORCAROUTER_API_KEY,
      baseURL: ORCAROUTER_BASE_URL,
    });
    const response = await client.chat.completions.create({
      model: LIVE_MODEL_ID,
      messages: [{ role: "user", content: "Reply with exactly OK." }],
      max_tokens: 16,
    });
    expect(response.choices[0]?.message?.content?.trim()).toMatch(/^OK[.!]?$/);
  }, 60_000);

  it("rejects an obviously invalid API key with a clean 401", async () => {
    const client = new OpenAI({
      apiKey: "sk-orca-clearly-invalid-key-for-test",
      baseURL: ORCAROUTER_BASE_URL,
    });
    await expect(
      client.chat.completions.create({
        model: LIVE_MODEL_ID,
        messages: [{ role: "user", content: "ping" }],
        max_tokens: 4,
      }),
    ).rejects.toMatchObject({ status: 401 });
  }, 30_000);
});
