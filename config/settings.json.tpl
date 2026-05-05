{
  "permissions": {
    "allow": [
      "WebFetch(domain:docs.anthropic.com)",
      "WebFetch(domain:opencode.ai)",
      "WebFetch(domain:geminicli.com)",
      "WebFetch(domain:github.com)"
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "bash @@CLAUDE_DIR@@/statusline-command.sh"
  },
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
    ]
  },
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
