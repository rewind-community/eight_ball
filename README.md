# EightBall

[![Gem Version](https://badge.fury.io/rb/eight_ball.png)](https://badge.fury.io/rb/eight_ball) ![Build](https://github.com/rewindio/eight_ball/workflows/tag-and-release/badge.svg)

EightBall is a feature toggle querying gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'eight_ball'
```

And then execute:

```ruby
bundle
```

Or install it yourself as:

```ruby
gem install eight_ball
```

## Example Usage

```ruby
require 'eight_ball'

# This could be read from the filesystem or be the response from an external service, etc.
json_input = %(
  [{
    "name": "Feature1",
    "enabledFor": [{
      "type": "range",
      "parameter": "accountId",
      "min": 1,
      "max": 10
    }],
    "disabledFor": [{
      "type": "list",
      "parameter": "accountId",
      "values": [2, 3]
    }]
  }]
)

# Transform the JSON into a list of Features
marshaller = EightBall::Marshallers::Json.new
features = marshaller.unmarshall json_input

# Tell EightBall about these Features
EightBall.provider = EightBall::Providers::Static.new features

# Away you go
EightBall.enabled? "Feature1", { accountId: 4 } # true
EightBall.enabled? "Feature1", { accountId: 2 } # false
```

More examples [here](examples)

## Concepts

### Feature

A Feature is a part of your application that can be enabled or disabled based on various conditions. It has the following attributes:

- `name`: The unique name of the Feature.
- `enabledFor`: An array of Conditions for which the Feature is enabled.
- `disabledFor`: An array of Conditions for which the Feature is disabled.

### Condition

A Condition must either be `true` or `false`. It describes when a Feature is enabled or disabled.

#### Supported Conditions

- [Always](lib/eight_ball/conditions/always.rb):  This condition is always satisfied.
- [List](lib/eight_ball/conditions/list.rb): This condition is satisfied if the given value belongs to its list of accepted values.
- [Never](lib/eight_ball/conditions/never.rb): This condition is never satisfied.
- [Range](lib/eight_ball/conditions/range.rb): This condition is satisfied if the given value is within the specified range (inclusive).
- [Percentage](lib/eight_ball/conditions/percentage.rb): This condition is satisfied for a deterministic, sticky subset of subjects sized to `percentage` percent. Bucketing is salted by the flag name so a subject is decorrelated across flags. `parameter` is required. Wire form: `{"type":"percentage","percentage":<0..100>,"parameter":"account_id"}`.

#### List value coercion

By default a `list` matches by exact type, so an integer value never matches a string (and vice versa). Set `coerce: true` on a list to compare both sides as strings, so an integer-authored list matches a string caller. The default stays exact, and the field is serialized only when enabled. Wire form: `{"type":"list","parameter":"account_id","values":[2,3],"coerce":true}`.

Coercion is exact string comparison (`value.to_s`), not numeric or fuzzy: `1.0` does not match a `[1]` list, and `nil`/`""` share a string form. It is intended for scalar id/name lists. Cross-version note: a reader on a pre-`coerce` gem ignores the field and matches exactly, so a `coerce:true` flag can evaluate differently across gem versions until every reader is upgraded.

#### Sticky percentage bucketing

The `percentage` condition buckets a subject deterministically:

```
bucket = Integer(Digest::SHA256.hexdigest("#{flagName}:#{value}")[0, 8], 16) % 100
satisfied  iff  bucket < percentage
```

The salt is the **flag name**, so the same `account_id` lands in independent buckets across different flags. `value` is stringified before hashing. Any reimplementation must reproduce it exactly to produce the same buckets.

**Re-randomizing requires a rename.** Because the salt is the flag name, an experiment cannot be re-randomized on the same flag. The salt is stable for the life of the name (this is what decorrelates a subject across flags), so a subject's bucket for a given flag is fixed forever. Changing `percentage` only moves the threshold (it does not reshuffle buckets); to draw fresh buckets, rename the flag.

**Requires the bucketing parameter.** Like every parameterized condition, `percentage` requires its bucketing value (the `parameter` it was configured with) in the evaluation bag. If it is absent, evaluation raises `ArgumentError`; supply it or rescue.

### Metadata

A Feature may carry an optional, eval-agnostic `metadata` object (`type`, `owner`, `expires_at`, all optional strings). It is preserved through marshall/unmarshall and ignored during evaluation. Its keys go through the same case conversion as the rest of the wire format (e.g. `expires_at` serializes as `expiresAt`) and come back symbol-keyed after unmarshall.

### Provider

A Provider is able to give EightBall the list of Features it needs to answer queries.

#### Supported Providers

- [HTTP](lib/eight_ball/providers/http.rb): Connect to a URL and use the given Marshaller to convert the response into a list of Features.
- [Static](lib/eight_ball/providers/static.rb): Once initialized with a list of Features, always provides that same list of Features.

### RefreshPolicies

Some Providers are able to automatically "refresh" their list of Features using a RefreshPolicy.

#### Supported RefreshPolicies

- [Interval](lib/eight_ball/providers/refresh_policies/interval.rb): The data is considered fresh for a given number of seconds, after which it is considered stale and should be refreshed.

### Marshallers

A Marshaller converts Features to and from another format.

#### Supported Marshaller

- [JSON](lib/eight_ball/marshallers/json.rb)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

### Documenting

Documentation is written using [yard](https://yardoc.org/) syntax. You can view the generated docs by running `yard server` and going to `http://127.0.0.1:8808/docs/EightBall`

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rewindio/eight_ball.
