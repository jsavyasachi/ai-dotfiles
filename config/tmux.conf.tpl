# Pass AI progress bars and notifications through to Ghostty.
set -g allow-passthrough on

# Preserve truecolor inside tmux panes.
set -ga terminal-overrides ",tmux-256color:Tc"

# Keep interactive sessions responsive and recoverable.
set -g escape-time 0
set -g history-limit 100000
set -g set-clipboard on
set -g mouse on

# Silence "tmux focus-events off" warnings from AI terminal interfaces.
set -g focus-events on

# Preserve modified keys such as Shift+Enter for AI terminal interfaces.
set -s extended-keys on
set -as terminal-features ',xterm*:extkeys'
