# Pass AI progress bars and notifications through to Ghostty.
set -g allow-passthrough on

# Preserve modified keys such as Shift+Enter for AI terminal interfaces.
set -s extended-keys on
set -as terminal-features ',xterm*:extkeys'
