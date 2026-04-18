import { readFileSync } from "node:fs";

/** @typedef {import("@opencode-ai/plugin").Plugin} Plugin */

function promptFilename(model) {
  const modelId = String(model?.api?.id ?? "").toLowerCase();
  return modelId.includes("gpt") ? "./prompt-gpt.txt" : "./prompt-other.txt";
}

function isBasePrompt(system) {
  return system.startsWith("You are OpenCode") || system.startsWith("You are opencode");
}

function replaceBasePrompt(system, replacement) {
  const boundary = system.indexOf("\nYou are powered by the model named ");
  if (boundary === -1) {
    console.log("[Plugin Debug] Failed: Boundary '\\nYou are powered by...' not found.");
    return null;
  }

  const prefix = system.slice(0, boundary);
  if (!isBasePrompt(prefix)) {
    console.log("[Plugin Debug] Failed: isBasePrompt returned false. Prefix starts with:", JSON.stringify(prefix.slice(0, 50)));
    return null;
  }

  return replacement + system.slice(boundary);
}

/** @type {Plugin} */
export const SlimPromptPlugin = async () => ({
  "experimental.chat.system.transform": async (input, output) => {
    console.log("[Plugin Debug] System transform hook triggered!");
    console.log("[Plugin Debug] Model:", input?.model?.api?.id);
    
    const [system] = output.system;
    if (!system) {
      console.log("[Plugin Debug] No system prompt found in output.system");
      return;
    }

    const filename = promptFilename(input?.model);
    console.log("[Plugin Debug] Loading prompt file:", filename);
    
    const shortPrompt = readFileSync(
      new URL(filename, import.meta.url),
      "utf8",
    ).trim();
    
    const next = replaceBasePrompt(system, shortPrompt);
    if (!next) {
      console.log("[Plugin Debug] Base prompt replacement failed (could not find base prompt format).");
      return;
    }

    console.log("[Plugin Debug] Successfully replaced base prompt!");
    output.system.splice(
      0,
      output.system.length,
      next,
    );
  },
});

export default SlimPromptPlugin;
