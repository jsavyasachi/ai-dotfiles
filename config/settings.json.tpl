{
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
