# Changelog

## [3.5.0]

- Fix `Feature#enabled?` so a direction's conditions are evaluated as the documented OR. `any_satisfied?` used `return` inside an `any?` block, which exits the method, so the first condition without a parameter became the whole verdict and later conditions were never consulted. A `never` ahead of a matching `list` evaluated to false in `enabledFor`, and a `never` ahead of a matching entry in `disabledFor` stopped that entry from disabling the feature.

  Behaviour is unchanged for any direction holding a single condition, and for any direction whose parameterless condition is satisfied (an `always` still short-circuits the direction, so nothing after it is reached).

  **Upgrade note.** The affected shape is a direction holding an UNSATISFIED parameterless condition (in practice a `never`) followed by a parameterized one. Those later conditions are now evaluated, which has two consequences. First, the verdict can change in either direction, and in both cases the later condition starts doing what it says: an `enabledFor` allow entry begins enabling (`false` to `true`), and a `disabledFor` deny entry begins disabling (`true` to `false`). Second, evaluation can now raise where it previously answered a boolean, because the later condition's parameter is required exactly as it would be if that condition stood alone: `ArgumentError, "Missing parameter ..."` when the bag lacks the key, and for a `range` whose bag value is the wrong type, `ArgumentError, "comparison of String with 1 failed"`. Treating an absent parameter as unsatisfied instead was rejected deliberately, because it would let a `disabledFor` entry silently stop disabling a feature when a caller omits the key. Audit any definition with more than one condition in a direction before upgrading.

- Reject any parameterized condition (`list`, `range`, `percentage`) that has no `parameter`, or only whitespace. Such a condition evaluates against a subject value it has no way to look up, and previously raised `wrong number of arguments` on every evaluation for every caller. It is now treated as unbuildable, so the owning feature fails closed like any other invalid entry. `always` and `never` take no value and are unaffected.

- Ignore `nil` entries in a Feature's condition lists instead of raising `NoMethodError` while evaluating. The marshaller already dropped them when writing, so reading now matches writing.

- Derive `un_evaluable?` from the conditions rather than holding it only as state set after construction, so a Feature rebuilt from another's conditions stays failed closed instead of silently becoming enabled again.

## [3.4.0]

- Add an opt-in `coerce` boolean to the `list` condition. When `true`, values and the tested input are compared as strings, so a list authored with integers matches a string caller (and vice versa). Defaults to exact-type matching, so existing definitions are unchanged; the flag is serialized only when enabled.

## [3.3.3]

- Add `.compact` before each `.map(&:to_wire)` so stray nil conditions are
dropped instead of blowing up serialization

## [3.3.2]

- Fix the `tag-and-release` workflow to create the release tag with the `rewind-community-tagger` GitHub App token (`TAGGER_APP_ID`/`TAGGER_PRIVATE_KEY`) instead of the default `GITHUB_TOKEN`, which the organization `rewind-tag` ruleset does not permit to create `v*` tags (the previous release failed with `Reference update failed`).

## [3.3.1]

- Fix the `tag-and-release` workflow: grant the release job `contents: write` so tag and GitHub Release creation succeed. The repository's default GitHub Actions token permission had been changed to read-only, which broke the release step with `Resource not accessible by integration`.

## [3.3.0]

- Add `percentage` condition for sticky A/B bucketing. Canonical algorithm: `bucket = Integer(SHA256("<flagName>:<value>")[0,8], 16) % 100`, satisfied iff `bucket < percentage`; salted by flag name; buckets on a caller-supplied parameter.
- Harden JSON unmarshalling: a flag containing an unknown or malformed condition (unknown `type`, or a known type with invalid params) now evaluates to `false` (OFF) and logs a warning, instead of raising and blacking out the entire feature set. Other flags in the blob are unaffected.
- Add optional top-level `metadata` (`type`, `owner`, `expires_at`) to `Feature`, preserved through marshall/unmarshall and ignored during evaluation.

## [3.2.0]

- Upgrade Ruby to 3.4.5

## [3.1.1]

- Loosen `required_ruby_version` to `>= 3.2` for Edge compatibility (EC-4270)

## [3.1.0]

- Upgrade Ruby to 3.3.10

## [3.0.1]

- Fix release workflow to use ruby/setup-ruby instead of actions/setup-ruby

## [3.0.0]

- Update to ruby 3.2.8
- Address deprecation warning for URI.regexp for ruby 3.2 and 3.4
- Update to bundler 2

## [2.2.1]

- Switch release to github actions

## [2.2.0]

- Add `==` to `Feature` and `Conditions`

## [2.1.0]

- Add `features` parameter to `EightBall.marshall` to allow marshalling any Features, not just the ones
   from the configured Provider.

## [2.0.0]

- [BREAKING] `Parsers` have been replaced with `Marshallers`, allowing bi-directional conversions
- Added `EightBall.marshall` as a way to output the Feature list to an external format (e.g. to create a JSON file)
- Added `EightBall.features` as a shortcut to `EightBall.provider.features`
- Testing framework has been moved from Minitest to rspec
- Updated dev dependencies

## [1.0.5]

Security: Update rake to >= 12.3.3

## [1.0.3]

Update .travis.yml

## [1.0.2]

Update .travis.yml

## [1.0.1]

Security: Update yard 0.9.16 -> 0.9.20

## [1.0.0]

Initial release!
