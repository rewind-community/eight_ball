# Changelog

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
