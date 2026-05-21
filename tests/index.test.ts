import { describe, expect, it } from "vitest";
import { applyOrcarouterConfig, ORCAROUTER_DEFAULT_MODEL_REF } from "../onboard.js";
import {
  buildOrcarouterProvider,
  normalizeOrcaRouterBaseUrl,
  ORCAROUTER_BASE_URL,
  ORCAROUTER_DEFAULT_MODEL_ID,
} from "../provider-catalog.js";

describe("orcarouter provider-catalog", () => {
  it("returns the canonical api.orcarouter.ai base URL", () => {
    const provider = buildOrcarouterProvider();
    expect(provider.baseUrl).toBe(ORCAROUTER_BASE_URL);
    expect(provider.api).toBe("openai-completions");
  });

  it("lists orcarouter/auto as the first model", () => {
    const provider = buildOrcarouterProvider();
    expect(provider.models?.[0]?.id).toBe(ORCAROUTER_DEFAULT_MODEL_ID);
    expect(provider.models?.[0]?.name).toBe("OrcaRouter Auto");
  });

  it("includes flagship reference models per shared notes §3", () => {
    const provider = buildOrcarouterProvider();
    const ids = (provider.models ?? []).map((m) => m.id);
    expect(ids).toContain("orcarouter/auto");
    expect(ids).toContain("openai/gpt-5.5");
    expect(ids).toContain("anthropic/claude-opus-4.7");
    expect(ids).toContain("google/gemini-3-flash-preview");
    expect(ids).toContain("deepseek/deepseek-v4-pro");
  });

  it("normalizes legacy marketing base URLs to api. subdomain", () => {
    expect(normalizeOrcaRouterBaseUrl(ORCAROUTER_BASE_URL)).toBe(ORCAROUTER_BASE_URL);
    expect(normalizeOrcaRouterBaseUrl("https://orcarouter.ai/v1")).toBe(ORCAROUTER_BASE_URL);
    expect(normalizeOrcaRouterBaseUrl("https://www.orcarouter.ai/v1")).toBe(ORCAROUTER_BASE_URL);
    // Trailing slash is stripped
    expect(normalizeOrcaRouterBaseUrl("https://api.orcarouter.ai/v1/")).toBe(ORCAROUTER_BASE_URL);
  });

  it("rejects unrelated base URLs (returns undefined so user proxies pass through)", () => {
    expect(normalizeOrcaRouterBaseUrl("https://example.com/v1")).toBeUndefined();
    expect(normalizeOrcaRouterBaseUrl("https://openrouter.ai/api/v1")).toBeUndefined();
    expect(normalizeOrcaRouterBaseUrl("")).toBeUndefined();
    expect(normalizeOrcaRouterBaseUrl(undefined)).toBeUndefined();
  });
});

describe("orcarouter onboard", () => {
  it("sets the primary agent model to orcarouter/auto", () => {
    const cfg = applyOrcarouterConfig({});
    const model = cfg.agents?.defaults?.model;
    const primary = typeof model === "string" ? model : model?.primary;
    expect(primary).toBe(ORCAROUTER_DEFAULT_MODEL_REF);
  });

  it("seeds an OrcaRouter alias for the default model ref", () => {
    const cfg = applyOrcarouterConfig({});
    expect(cfg.agents?.defaults?.models?.[ORCAROUTER_DEFAULT_MODEL_REF]?.alias).toBe("OrcaRouter");
  });

  it("preserves existing user-set aliases", () => {
    const cfg = applyOrcarouterConfig({
      agents: {
        defaults: {
          models: {
            [ORCAROUTER_DEFAULT_MODEL_REF]: { alias: "MyRouter" },
          },
        },
      },
    });
    expect(cfg.agents?.defaults?.models?.[ORCAROUTER_DEFAULT_MODEL_REF]?.alias).toBe("MyRouter");
  });
});
