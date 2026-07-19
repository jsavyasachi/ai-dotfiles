# Pass AI progress bars and notifications through to Ghostty.
set -g allow-passthrough on

# Silence "tmux focus-events off" warnings from AI terminal interfaces.
set -g focus-events on

# Preserve modified keys such as Shift+Enter for AI terminal interfaces.
set -s extended-keys on
set -as terminal-features ',xterm*:extkeys'
