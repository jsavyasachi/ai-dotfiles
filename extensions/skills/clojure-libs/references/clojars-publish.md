# Clojars release runbook

Tactical steps for releasing to Clojars. Read this from the `clojure-libs` skill at
release time.

**The release path is CI, not a local deploy.** Pushing a `v*` tag is the deliberate
"this is worth a release" signal; nothing publishes on an ordinary commit. Never
publish from a laptop unless CI is genuinely unavailable.

## One-time per repo: seed the GitHub secrets

`release.yml` authenticates with two repository secrets:

```bash
gh secret set CLOJARS_USERNAME -R <you>/<lib>   # the Clojars username, see gotcha below
gh secret set CLOJARS_PASSWORD -R <you>/<lib>   # a Clojars DEPLOY TOKEN, not the login password
```

Pull both from your password manager when prompted. This is the only step that needs
the vault, and it happens once per repository. After that, releases need no local
credentials at all, so nothing secret ever touches a repo or a shell history.

## Release

```bash
# build.clj `version` is the source of truth; release.yml fails the run if the tag
# does not match it.
git push origin main
git tag v<x.y.z> && git push origin v<x.y.z>
gh run watch <id> --exit-status
```

`release.yml` verifies the tag against `build.clj`, runs the tests, deploys with
`clojure -T:build deploy`, and creates the GitHub Release.

## Verify (mandatory - do not skip)

Clojars is **immutable**: a published version can never be replaced or withdrawn, and
a redeploy returns `403 Non-SNAPSHOT redeploy`. A green CI run is **not** proof of
publication, and a red run is **not** proof of failure. Always check the artifact
itself:

```bash
curl -s https://clojars.org/api/artifacts/net.clojars.<u>/<lib> | grep -o '"latest_release":"[^"]*"'
curl -s -o /dev/null -w '%{http_code}\n' \
  https://repo.clojars.org/net/clojars/<u>/<lib>/<v>/<lib>-<v>.jar   # want 200
curl -s -o /dev/null -w '%{http_code}\n' \
  https://repo.clojars.org/net/clojars/<u>/<lib>/<v>/<lib>-<v>.pom   # want 200
```

cljdoc auto-builds at `https://cljdoc.org/d/net.clojars.<u>/<lib>/<v>` within minutes,
and only re-renders on a deploy, so doc-only changes need a patch release to appear.
For a companion artifact, confirm the **core jar excludes** the companion's classes
(`jar tf target/<lib>-<v>.jar | grep <CompanionClass>` should be empty).

## Gotchas

- **`b/write-pom` emits no `<licenses>`, and Clojars hard-rejects a license-less POM**
  with `403 "the POM file does not include a license"`. The rejected upload still
  **occupies that version**, so it can never be redeployed and you must bump. This
  burned a `0.1.0`. Leiningen avoids it because `project.clj` `:license` flows into the
  POM automatically; deps.edn libs must pass it explicitly:

  ```clojure
  (b/write-pom {... :pom-data [[:licenses
                                [:license
                                 [:name "Eclipse Public License 2.0"]
                                 [:url "https://www.eclipse.org/legal/epl-2.0/"]
                                 [:distribution "repo"]]]]})
  ```

  Verify **before** tagging: `clojure -T:build jar`, then grep
  `target/classes/META-INF/maven/<group>/<artifact>/pom.xml` for `<licenses>`.
- **A lein repo's `:deploy-repositories` key must be `"clojars"`**, matching the
  `lein deploy clojars` command. Keyed `"releases"` instead, lein silently ignores the
  project repo (and its `:sign-releases false`) and falls back to its built-in clojars
  repo, which **signs**, so CI dies with `gpg: signing failed: No secret key`. Audit
  with `grep -l '"releases"' <repos>/*/project.clj`.
- **`CLOJARS_USERNAME` is the Clojars username, not the GitHub handle.** Using the
  GitHub handle returns a `401` even with a valid token. This burned two deploy
  attempts once.
- **Group choice**: `net.clojars.<u>` is auto-verified and needs zero setup. Do NOT
  use `io.github.<user>`; it requires a `clojars-<username>` verification repo and is
  fiddly.
- **A red release run may still have published.** During a GitHub Actions outage the
  deploy step can fail without publishing, while the logs API 503s and hides the
  cause. Verify on Clojars first, then `gh run rerun <id> --failed` once GitHub
  recovers, rather than bumping the version.
- **Hardcoded artifact paths.** If the repo deploys via an `:deploy` alias with
  `:artifact "target/<lib>-1.2.3.jar"`, that string does not track `build.clj`
  version. Bump both, and build the jar locally to confirm the filename matches
  before tagging.
- **Multi-artifact repos**: guard each deploy step with a Clojars existence check, or
  an unchanged companion 403s and false-reds the run.
- **Deploy a companion before its dependent's CI runs.** A dependent's CI fails
  `Could not find artifact ...:jar:<v>` until the dependency is on Clojars. Publish the
  dependency first, then re-run the dependent's CI (`gh run rerun <id> -R <you>/<dependent>`).
- **Newer-JDK artifacts** (FFM, JDK 22+) need a JDK at or above their target in the
  release workflow's `setup-java` step; the JDK-8 libs release with any JDK 8+.
