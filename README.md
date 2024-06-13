# AWS Tags mod for Flowpipe

Pipelines to detect and correct AWS resource tag keys and values based on a provided ruleset.

## Documentation

- **[Hub →](https://hub.flowpipe.io/mods/turbot/aws_tags)**

## Getting Started

### Requirements

Docker daemon must be installed and running. Please see [Install Docker Engine](https://docs.docker.com/engine/install/) for more information.

### Installation

Download and install Flowpipe (https://flowpipe.io/downloads) and Steampipe (https://steampipe.io/downloads). Or use Brew:

```sh
brew install turbot/tap/flowpipe
brew install turbot/tap/steampipe
```

Install the AWS plugin with [Steampipe](https://steampipe.io):

```sh
steampipe plugin install aws
```

Steampipe will automatically use your default AWS credentials. Optionally, you can [setup multiple accounts](https://hub.steampipe.io/plugins/turbot/aws#multi-account-connections) or [customize AWS credentials](https://hub.steampipe.io/plugins/turbot/aws#configuring-aws-credentials).

Create a `credential_import` resource to import your Steampipe AWS connections:

```sh
vi ~/.flowpipe/config/aws.fpc
```

```hcl
credential_import "aws" {
  source      = "~/.steampipe/config/aws.spc"
  connections = ["*"]
}
```

For more information on importing credentials, please see [Credential Import](https://flowpipe.io/docs/reference/config-files/credential_import).

For more information on credentials in Flowpipe, please see [Managing Credentials](https://flowpipe.io/docs/run/credentials).

Clone the mod:

```sh
mkdir aws-tags
cd aws-tags
git clone git@github.com:turbot/flowpipe-mod-aws-tags.git
```

Install the dependencies:

```sh
flowpipe mod install
```

### Configuration

> TODO: General set-up configuration, etc.

Prior to running a detect and correct pipeline for a specific resource, you will need to configure the rules for the resource tag keys as well as another variable for the resource tag values.

When configuring these rules you will be able to specify lists of `pattern strings` for the `allow`, `remove` and `update` property values, these can either be in the format of `value` or `operator:value`.

- `value` is an exact match on the given value, using the `=` operator in postgres. For example `bob` will only ever match exactly on `bob`.
- `operator:value` is for specifying a postgres operator and then the value (or regex/pattern/etc) that will be applied by that operator. The supported operators are:
  - `~` 
  - `~*`
  - `like`
  - `ilike`
  - `=` 
  - `!=`

The variables which need to be configured (per resource) are in the following shapes defined below:

**Key Example:**
```hcl
variable "s3_buckets_with_incorrect_tag_keys_rules" {
  type = object({
    require = map(string)
    allow   = list(string)
    remove  = list(string)
    update  = map(list(string))
  })
}
```

- `require` : This is a set of `key:value` pairs where if the given key doesn't exist on a resource it can be applied with the provided value.
- `allow`   : This is a list of pattern strings, if not empty any keys which do not match any of the patterns will recommended for removal.
- `remove`  : This is a list of pattern strings, if not empty any keys matching any of the patterns will be recommended for removal.
- `update`  : This is a map of replacement tag keys and pattern strings, where any tag key matching a pattern will be recommended to be created with the new tag key (& existing value), while the old tag key will be recommended for removal.

**Value Example:**
```hcl
variable "s3_buckets_with_incorrect_tag_values_rules" {
  type = map(object({
    default = string
    allow   = list(string)
    remove  = list(string)
    update  = map(list(string))
  }))
}
```

- `default` : This is a string `value` which will be applied to the tag with a key matching the parent `map` key, if the key matches a pattern in `remove` or doesn't match any pattern given in `allow`.
- `allow`   : This is a list of patterns to apply to the value of a given tag key. If empty all values are allowed, if non-empty, any value for given key not matching a pattern here will have the value replaced by the defined `default`.
- `remove`  : This is a list of patterns to apply to the value of a given tag key. If the value matches any of these patterns, it will be replaced by the value defined as `default`.
- `update`  : This is a map of replacement values (map keys), to apply to the given tag key if the value matches any of the patterns defined in the list.

Below are some examples of using these rules to fix common tagging issues, for simplicity these will assume you configure the rules in `fpvars` files as opposed to passing them on the command line as arguments, although this is possible.

#### Prohibited Tag Keys

We may have some keys on our resources which we want to remove, for example `password`, this can be achieved by simply setting this in the `remove` property of our variable as shown below:

```hcl
# file: prohibited.fpvars
# other configuration options omitted for brevity
s3_buckets_with_incorrect_tag_keys_rules = {
  require = {}
  allow   = []
  remove  = ["password"]
  update  = {}
}
```

We should then be able to run the below command referencing our `prohibited.fpvars` file, to perform detection and correction of resources which violate the provided rules:

```sh
flowpipe pipeline run detect_and_correct_s3_buckets_with_incorrect_tag_keys --var-file=prohibited.fpvars
```

A more realistic example however may be to check if as have `password` anywhere in the key, in any casing, as well as other key phrases like ending with `key` or starting with `secret`:

```hcl
# file: prohibited.fpvars
# other configuration options omitted for brevity
s3_buckets_with_incorrect_tag_keys_rules = {
  require = {}
  allow   = []
  remove  = ["~*:password", "ilike:secret%", "~*:key$"]
  update  = {}
}
```

An alternative approach would be to remove all tags which do not match our expecting / desired tag keys based, this can be done by using the `allow` property instead. For example, lets assume that we only want tags which are `env`, `owner`, `cost_center` or prefixed with our company name `turbot_`, we could use the following:

```hcl
# file: prohibited.fpvars
# other configuration options omitted for brevity
s3_buckets_with_incorrect_tag_keys_rules = {
  require = {}
  allow   = ["env", "owner", "cost_center", "ilike:turbot\_%"]
  remove  = []
  update  = {}
}
```

Then running the below command should recommend we remove any other tags.

```sh
flowpipe pipeline run detect_and_correct_s3_buckets_with_incorrect_tag_keys --var-file=prohibited.fpvars
```

#### Mandatory Tags

Another common problem is that we may have tags which we need to have on all our resources, for this we can find resources without these tags and apply a default value using the `require` rule.

For example, we should ensure we have an `env` tag, in the below example we will set the value to be `not set`, we may also want to ensure we have an `owner` tag our default owner will be `bob`.

```hcl
# file: mandatory.fpvars
# other configuration options omitted for brevity
s3_buckets_with_incorrect_tag_keys_rules = {
  require = {
    env   = "not set"
    owner = "bob" 
  }
  allow   = []
  remove  = []
  update  = {}
}
```

We can then apply this to our resources by running the relevant detect and correct pipeline passing our file to set the rules:

```sh
flowpipe pipeline run detect_and_correct_s3_buckets_with_incorrect_tag_keys --var-file=mandatory.fpvars
```

#### Standardizing / Renaming Tag Keys

Over time, tag key standards may change meaning that we may need to change the key but retain our existing value. This can be achieved by using our `update` property, shown below is an example where we want the following changes:

- Case-insensitive matching on `environment`, `env` or a typo `enviroment` => `env`
- Case-insensitive matching on `cc`, `costcenter`, `cost_center` or the common typo using `re` => `cost_center`

```hcl
# file: standards.fpvars
# other configuration options omitted for brevity
s3_buckets_with_incorrect_tag_keys_rules = {
  require = {}
  allow   = []
  remove  = []
  update  = {
    env         = ["~*:^environment$", "~*:^env$", "enviroment"]
    cost_center = ["ilike:cc","~*:^cost_cent[er|re]$", "~*:^costcent[er|re]$"]
  }
}
```

Running these rules will then detect any matches, and for each recommend that we add the new tag with the existing matched tags value and then remove the original matched tag:

```sh
flowpipe pipeline run detect_and_correct_s3_buckets_with_incorrect_tag_keys --var-file=standards.fpvars
```

#### Combining Key Rules

> TODO: Explain how to combine the rules and the ordering of how these are processed.

> TODO: Might be worth converting this whole area to more little lisper where we explain the rule properties one at a time and slowly build the complex example?

```hcl
# file: keys.fpvars
# other configuration options omitted for brevity
s3_buckets_with_incorrect_tag_keys_rules = {
  require = {
    env         = "not set"
    owner       = "default_owner"
    cost_center = "default_cc" 
  }
  allow   = ["env", "owner", "cost_center", "~*:^turbot"]
  remove  = []
  update  = {
    env         = ["~*:^environment$", "~*:$env$", "enviroment"]
    cost_center = ["~*:cc","~*:^cost_cent[er|re]$", "~*:^costcent[er|re]$"]
  }
}
```

```sh
flowpipe pipeline run detect_and_correct_s3_buckets_with_incorrect_tag_values --var-file=keys.fpvars
```

#### Standardizing / Correcting Typos In Tag Values

In a similar fashion to keys, expected values can change over time and may need to be adjusted, this can be done using our `update` property on our value rules.

For example our `env` key, we may now want to support short versions `dev`, `prod`, `qa`, instead of previously used long names `development`, `production`, `quality_assurance`. 

```hcl
# file: standards.fpvars
# other configuration options omitted for brevity
s3_buckets_with_incorrect_tag_values_rules = {
  env = {
    default = ""
    allow   = []
    remove  = []
    update  = {
      prod = ["~*:^production$", "~*:^produktion$"]
      dev  = ["ilike:devel%"]
      qa   = ["~*:^quality_ass"]
    }
  }
}
```

We should then be able to run our detect and correct pipeline for the specific resource with incorrect tag values and ascertain which values will be updated.

```sh
flowpipe pipeline run detect_and_correct_s3_buckets_with_incorrect_tag_values --var-file=standards.fpvars
```

#### Expected/Invalid Tag Values

In a similar approach to keys, values may also want to be within an expected set of values / patterns. This can be done per key to specify an allowed set of values and a default value to apply if any values do not match one of the allowed patterns.

The below example demonstrates ensuring that our `env` tag has values of `dev`, `prod`, `qa` or `not set` and if any other value is detected, it will be recommended to be changed to `not set`, similarly we also state that `cost_centre` should be numeric, if not we replace it with our default.

```hcl
# file: expected_values.fpvars
# other configuration options omitted for brevity
s3_buckets_with_incorrect_tag_values_rules = {
  env = {
    default = "not set"
    allow   = ["dev", "prod", "qa", "not set"]
    remove  = []
    update  = {}
  }
  cost_center = {
    default = "0123456789"
    allow   = ["~:^[0-9]+$"]
    remove  = []
    update  = {}
  }
}
```

We should then be able to run our detect and correct pipeline for the specific resource with incorrect tag values and ascertain which values will be updated.

```sh
flowpipe pipeline run detect_and_correct_s3_buckets_with_incorrect_tag_values --var-file=expected_values.fpvars
```

#### Combining Value Rules

> TODO: Explain how to combine the rules and the ordering of how these are processed.

> TODO: Might be worth converting this whole area to more little lisper where we explain the rule properties one at a time and slowly build the complex example?

```hcl
# file: values.fpvars
# other configuration options omitted for brevity
s3_buckets_with_incorrect_tag_values_rules = {
  env = {
    default = "not set"
    allow   = ["dev", "prod", "qa", "not set"]
    remove  = []
    update  = {
      prod = ["~*:^production$", "~*:^produktion$"]
      dev  = ["ilike:dev%"]
      qa   = ["~*:^quality_ass"]
    }
  }
  cost_center = {
    default = "0123456789"
    allow   = ["~:^[0-9]+$"]
    remove  = []
    update  = {}
  }
  owner = {
    default = "bob"
    allow   = []
    remove  = ["default_owner"]
    update  = {}
  }
}
```

```sh
flowpipe pipeline run detect_and_correct_s3_buckets_with_incorrect_tag_values --var-file=values.fpvars
```

## Open Source & Contributing

This repository is published under the [Apache 2.0 license](https://www.apache.org/licenses/LICENSE-2.0). Please see our [code of conduct](https://github.com/turbot/.github/blob/main/CODE_OF_CONDUCT.md). We look forward to collaborating with you!

[Flowpipe](https://flowpipe.io) and [Steampipe](https://steampipe.io) are products produced from this open source software, exclusively by [Turbot HQ, Inc](https://turbot.com). They are distributed under our commercial terms. Others are allowed to make their own distribution of the software, but cannot use any of the Turbot trademarks, cloud services, etc. You can learn more in our [Open Source FAQ](https://turbot.com/open-source).

## Get Involved

**[Join #flowpipe on Slack →](https://turbot.com/community/join)**

Want to help but don't know where to start? Pick up one of the `help wanted` issues:

- [Flowpipe](https://github.com/turbot/flowpipe/labels/help%20wanted)
- [AWS Tags Mod](https://github.com/turbot/flowpipe-mod-aws-tags/labels/help%20wanted)