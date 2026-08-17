{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["@@OPENCODE_DIR@@/OPENCODE.md", "@@OPENCODE_DIR@@/OUTPUT-STYLE.md"],
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": {
        "baseURL": "http://localhost:11434/v1"
      },
      "models": {
        "qwen2.5-coder:14b": {
          "name": "Qwen 2.5 Coder 14B (local)"
        }
      }
    }
  },
  "model": "ollama/qwen2.5-coder:14b"
}
