#!/usr/bin/env bash
# validate-skill-frontmatter.sh: cross-agent guard against broken YAML
# frontmatter in SKILL.md / extensions/commands/*.md files.
#
# Catches the two footguns that bite SKILL.md `description:` values:
#   1. `: ` (colon-space) in an unquoted scalar -> strict parsers (Codex)
#      hard-fail with "mapping values are not allowed in this context" and
#      skip the skill at load. Lenient parsers (Claude Code) tolerate it,
#      so it ships broken without the author noticing.
#   2. ` #` (space-hash) in an unquoted scalar -> YAML treats it as a comment
#      and silently TRUNCATES the value. The skill loads but its trigger
#      text is cut off.
#
# Tool-agnostic: pure bash + /usr/bin/ruby (ships with macOS, has YAML).
# Fix for both: single-quote the whole value.
#
# Usage: validate-skill-frontmatter.sh <file> [<file> ...]
# Exit:  0 = all valid, 1 = at least one invalid (details on stderr).
set -euo pipefail

[[ $# -gt 0 ]] || { echo "usage: $0 <file> [<file> ...]" >&2; exit 2; }

fail=0

for file in "$@"; do
  [[ -f "$file" ]] || continue

  # ruby does the real work: extract frontmatter, parse it, and additionally
  # flag silent ` #` truncation that YAML.safe_load would not raise on.
  if ! /usr/bin/ruby -ryaml - "$file" <<'RUBY'
file = ARGV[0]
text = File.read(file)

# Frontmatter is the block between the first two '---' fences.
unless text =~ /\A---\s*\n(.*?)\n---\s*(\n|\z)/m
  # No frontmatter block: not a skill/command file we gate. Pass.
  exit 0
end
fm = $1

begin
  data = YAML.safe_load(fm)
rescue => e
  msg = e.message.split("\n").first
  warn "  \033[31m✖\033[0m #{file}"
  warn "      YAML parse error: #{msg}"
  warn "      Fix: single-quote the offending value (likely a ': ' inside an unquoted scalar)."
  exit 1
end

unless data.is_a?(Hash)
  warn "  \033[31m✖\033[0m #{file}: frontmatter is not a mapping"
  exit 1
end

# Detect silent ' #' truncation: re-scan raw lines for unquoted scalars whose
# value contains ' #'. YAML already cut these, so safe_load won't complain.
bad = []
fm.each_line do |line|
  next unless line =~ /\A([A-Za-z0-9_-]+):[ \t]+(\S.*?)[ \t]*\z/
  key, raw = $1, $2
  # Quoted values are safe.
  next if raw =~ /\A".*"\z/ || raw =~ /\A'.*'\z/
  bad << key if raw.include?(' #')
end
unless bad.empty?
  warn "  \033[31m✖\033[0m #{file}"
  warn "      Unquoted ' #' truncates these key(s) at the hash: #{bad.join(', ')}"
  warn "      Fix: single-quote the whole value."
  exit 1
end

exit 0
RUBY
  then
    fail=1
  fi
done

exit $fail
