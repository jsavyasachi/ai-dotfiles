# Clojars publish runbook

Tactical steps for `lein deploy clojars`. Read this from the `clojure-lib-revival`
skill at publish time.

## Credentials (one-time, global - never in a repo)

Deploy creds live in **`~/.lein/profiles.clj`** (the `:user` profile), referencing
env vars so no secret touches any repo:

```clojure
{:user {:deploy-repositories
        [["clojars" {:url "https://repo.clojars.org"
                     :username :env/clojars_username
                     :password :env/clojars_password
                     :sign-releases false}]]}}
```

`project.clj` then needs **nothing** deploy-related (do not add a second
`:deploy-repositories` there - duplicate "clojars" entries fight the global one).
The Clojars **deploy token** (not the login password) is the value for
`clojars_password`.

## Deploy

Inject the token inline so it is never printed or written to disk:

```bash
cd <lib>
CLOJARS_USERNAME=<u> \
CLOJARS_PASSWORD="$(op item get Clojars --fields 'deploy token' --reveal)" \
lein deploy clojars
```

(`op` = 1Password CLI; the token lives in the item named **Clojars**, field
**deploy token**.) Success ends with `Sending …/<lib>-<v>.jar … to
https://repo.clojars.org/` and no `401`.

## Gotchas

- **1Password locked → empty token.** From a non-interactive shell a locked `op`
  returns nothing: `token length: 0`, `error: authorization timeout`, then a `401`.
  Touch ID cannot be prompted from a background process - **the user must run the
  deploy command themselves** so the prompt appears. Hand it to them verbatim.
- **Deploy a companion before its dependent's CI runs.** A dependent artifact's CI
  fails `Could not find artifact …:jar:<v>` until the dependency is on Clojars.
  Publish the dependency first, then re-run the dependent's CI
  (`gh run rerun <id> -R <you>/<dependent>`).
- **Newer-JDK artifacts** (e.g. FFM, JDK 22+) must be built/deployed with a JDK >=
  their target. Set `JAVA_HOME` to a 22+ JDK (e.g. Homebrew openjdk) for that
  `lein deploy`; the JDK-8 libs deploy with any JDK 8+.
- `git tag <v> && git push origin <v>` before/after deploy (bare tag, no `v`
  prefix if the upstream lineage used bare tags).

## Verify

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  https://repo.clojars.org/net/clojars/<u>/<lib>/<v>/<lib>-<v>.pom   # want 200
```
cljdoc auto-builds at `https://cljdoc.org/d/net.clojars.<u>/<lib>/<v>` within minutes.
For a companion artifact, confirm the **core jar excludes** the companion's classes
(`jar tf target/<lib>-<v>.jar | grep <CompanionClass>` → empty).
