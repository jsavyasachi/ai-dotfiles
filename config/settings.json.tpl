{
  "permissions": {
    "defaultMode": "auto",
    "allow": [
      "WebFetch(domain:docs.anthropic.com)",
      "WebFetch(domain:code.claude.com)",
      "WebFetch(domain:developers.openai.com)",
      "WebFetch(domain:opencode.ai)",
      "WebFetch(domain:geminicli.com)",
      "WebFetch(domain:github.com)"
    ]
  },
  "skillOverrides": {
    "tdd": "off",
    "readme-badges": "off",
    "devserver": "off",
    "file-docs": "off",
    "mermaid": "off",
    "opencode": "off",
    "use-railway": "off"
  },
  "statusLine": {
    "type": "command",
    "command": "bash @@CLAUDE_DIR@@/statusline-command.sh"
  },
  "outputStyle": "ai-dotfiles",
  "terminalProgressBarEnabled": true,
  "preferredNotifChannel": "ghostty",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash @@CLAUDE_DIR@@/dirty-tree-check.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash @@CLAUDE_DIR@@/hooks/configure-agents-reminder.sh",
            "timeout": 5
          }
        ]
      }
    ]
  },
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
