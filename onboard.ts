import {
  applyAgentDefaultModelPrimary,
  type OpenClawConfig,
} from "openclaw/plugin-sdk/provider-onboard";

export const ORCAROUTER_DEFAULT_MODEL_REF = "orcarouter/auto";

export function applyOrcarouterProviderConfig(cfg: OpenClawConfig): OpenClawConfig {
  const models = { ...cfg.agents?.defaults?.models };
  models[ORCAROUTER_DEFAULT_MODEL_REF] = {
    ...models[ORCAROUTER_DEFAULT_MODEL_REF],
    alias: models[ORCAROUTER_DEFAULT_MODEL_REF]?.alias ?? "OrcaRouter",
  };

  return {
    ...cfg,
    agents: {
      ...cfg.agents,
      defaults: {
        ...cfg.agents?.defaults,
        models,
      },
    },
  };
}

export function applyOrcarouterConfig(cfg: OpenClawConfig): OpenClawConfig {
  return applyAgentDefaultModelPrimary(
    applyOrcarouterProviderConfig(cfg),
    ORCAROUTER_DEFAULT_MODEL_REF,
  );
}
