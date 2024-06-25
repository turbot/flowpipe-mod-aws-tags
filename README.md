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

To start using this mod, you need to configure some [input variables](https://flowpipe.io/docs/build/mod-variables#input-variables).

The simplest way to do this is to copy the example file `tags.fpvars.example` to `tags.fpvars`, and then update the values as needed. Alternatively, you can pass the variables directly via the command line or environment variables. For more details on these methods, see [passing input variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables).

```sh
cp tags.fpvars.example tags.fpvars
vi tags.fpvars
```

> TODO: Docs on the core variables: database, approvers, etc.

### Configuring Tag Rules

The `base_tag_rules` variable is an object matching the below definition that allows you to define how tags should be managed on your resources. Let's break down each attribute and how you can configure it for specific use cases.

```hcl
variable "base_tag_rules" {
  type = object({
    add           = optional(map(string))
    remove        = optional(list(string))
    remove_except = optional(list(string))
    update_keys   = optional(map(list(string)))
    update_values = optional(map(map(list(string))))
  })
}
```

#### Add: Ensuring Resources Have Mandatory Tags

Lets say for example, you require all of your resources to have at least `environment` and `owner` tags, you can use the `add` attribute to apply these tags to resources which currently do not have the specific tag.

```hcl
base_tag_rules = {
  add = {
    environment = "unknown"
    owner       = "turbie"
  }
}
```

Here, you can see the map key is the tag you want to ensure exists on your resources and the value is the default value to apply.

#### Remove: Ensuring Resources Don't Have Prohibited Tags 

Overtime, tags can be built up on your resources for all kinds of reasons, you can use the `remove` attribute to clean up tags that're no longer wanted or allowed from your resources.

The below example shows how to remove any tags from our resources which are `password`, `secret` or `key`.

```hcl
base_tag_rules = {
  remove = ["password", "secret", "key"]
}
```

However; the above example will only cater for exact matches on those strings for the keys, as keys in AWS are case-insensitive, we would miss a tag like `Password` or `ssh_key` as these aren't exact matches.

In order to achieve these kind of matches, we support an `operator:pattern` syntax which takes a postgres operator and a pattern separated by a `:`, for more information on these see the [Supported Operators](#supported-operators) section. 

A more realistic approach would be to remove tags which contains `password`, begins with `secret` or ends with `key` and these should all be case-insensitive matches, this would look like the below example.

```hcl
base_tag_rules = {
  remove = ["~*:password", "ilike:secret%", "~*:key$"]
}
```

Any tags which do not match one of the patterns in the list will be retained.

#### Remove Except: Ensuring Resources Only Have Permitted Tags

Another approach to cleaning up your tags is to ensure that you only have those that're desired or permitted and all others are removed, you can use the `remove_except` attribute to define a list of patterns for retaining matching tags, where all other tags are desired to be removed.

As this is the inverse behavior of `remove`, it is recommended that you only use one or the other of these attributes, but they do follow the same `operator:pattern` matching behavior.

Lets say, that we want to ensure our resources **only** have the following tags:
- `environment`
- `owner`
- `cost_center`
- Any that are prefixed with our company name `turbot`.

This would look like the following example:

```hcl
base_tag_rules = {
  remove_except = ["environment", "owner", "cost_center", "~:^turbot"]
}
```

Any tags which do not match one of the above patterns will be removed from the resources.

#### Update Keys: Ensuring Tag Keys Are Standardized

Over time your tagging standards may change or you may have variants of the same tag that you wish to standardize, you can use the `update_keys` attribute to reconcile tags to a standardized set.

For example, we may have want to consolidate tags for `environment` and `cost_center` where we've previously used short-hand tags for our standard (`env` and `cc`), as well as remediate common spelling errors such as `enviroment` or `cost_centre`.

```hcl
base_tag_rules = {
  update_keys = {
    environment = ["env", "ilike:enviro%"]
    cost_center = ["cc", "~*:^cost_cent(er|re)$", "~*:^costcent(er|re)$"]
  }
}
```

Behind the scenes, this works by creating a new tag with the value of existing matched tag and then removing the existing matched tag.

#### Update Values: Ensuring Tag Values Are Standardized

In a similar fashion to keys, you may want to change the standards of the values over time or correct common typos, you can use the `update_values` attribute to reconcile values to expected standards.

This works in a similar way to `update_keys` except that there is an extra layer of nesting to group the updates on a per-key basis.

For example, lets say that you want to ensure the following happens:
- For `environment` tag, any previous short-hand or aliases are standardized into new long name standards.
- For `cost_center` tag, any values which have non-numeric characters are replaced by your default cost center.
- For `owner` tag, anything previously held by `Nathan` or `Dave` is now owned by `Bob`.

```hcl
base_tag_rules = {
  update_values = {
    environment = {
      production        = ["~*:^prod"]
      test              = ["~*:^test", "~*:^uat$"]
      development       = ["~*:^dev"]
      quality_assurance = ["~*:^qa$", "ilike:%quality%"]
    }
    cost_center = {
      "0123456789" = ["~:[^0-9]"]
    }
    owner = {
      Bob = ["~*:^nathan$", "ilike:Dave"]
    }
  }
}
```

<!-- TODO: Add documentation about `default` for non-matching values if we get this in. -->

#### Complete Tag Rules

Now that you understand each of the attributes available in the `base_tag_rules` object individually, you can combine them to create a complex ruleset for managing your resource tags. By leveraging multiple attributes together you can achieve sophisticated tagging strategies.

> Note: Using `remove` / `remove_except`
>
> Ideally, you should use either the `remove` or the `remove_except` attribute, but not both simultaneously. This ensures clarity in your tag removal logic and avoids potential conflicts.
>
> - `remove`: Use this to specify patterns of tags you want to explicitly remove.
>- `remove_except`: Use this to specify patterns of tags you want to retain, removing all others.

When using a combination of attributes to build a complex ruleset, they will be executed in the following order to ensure logical application of the rules:

1. `update_keys`: Start by updating any incorrect keys to be the new expected values.
2. `add`: Adds missing mandatory tags with a default value, this is done after updating the keys to ensure that if update has the same tag, the value isn't overwritten with the default but kept.
3. `remove`/`remove_except`: Will remove any tags no longer required based on the patterns provided and old tags which have been updated.
4. `update_values`: Finally once the tags have been established, the values will be reconciled as desired.

Lets combine some of the above examples to create a complex ruleset.

```hcl
base_tag_rules = {
  update_keys = {
    environment = ["env", "ilike:enviro%"]
    cost_center = ["cc", "~*:^cost_cent(er|re)$", "~*:^costcent(er|re)$"]
  }
  add = {
    environment = "unknown"
    owner       = "turbie"
    cost_center = "0123456789"
  }
  remove_except = [
    "environment", 
    "owner", 
    "cost_center", 
    "~:^turbot"
  ]
  update_values = {
    environment = {
      production        = ["~*:^prod"]
      test              = ["~*:^test", "~*:^uat$"]
      development       = ["~*:^dev"]
      quality_assurance = ["~*:^qa$", "ilike:%quality%"]
    }
    cost_center = {
      "0123456789" = ["~:[^0-9]"]
    }
    owner = {
      Bob = ["~*:^nathan$", "ilike:Dave"]
    }
  }
}
```

This ensures that:
- Firstly, the keys are updated, so we can safely perform next rules on those keys.
- Secondly, any missing required tags are added.
- Thirdly, any tags that are no longer required are removed.
- Finally, the values are updated as required.

#### Supported Operators

The below table shows the currently supported operators for pattern-matching.

| Operator | Purpose |
| -------- | ------- |
| `=`      | Case-sensitive exact match |
| `like`   | Case-sensitive pattern matching, where `%` indicates zero or more characters and `_` indicates a single character |
| `ilike`  | Case-insensitive pattern matching, where `%` indicates zero or more characters and `_` indicates a single character |
| `~`      | Case-sensitive pattern matching using `regex` patterns. | 
| `~*`     | Case-insensitive pattern matching using `regex` patterns. | 

If you attempt to use an operator *not* in the above table, the string will be processed as an exact match, e.g: `!~:^bob` wouldn't match anything that doesn't begin with `bob` but instead only matches if it is exactly `!~:^bob`.

<!--

#### Combining Key Rules

You can combine all of the properties to make more complex rule sets, which will apply the rules in the following order:
- `update`, will apply any corrections first, to ensure that the other rule options are working on a corrected set of tag keys.
- `require`, will then check the `updated` tag keys and if any `required` keys are missing, they will be added to the collection with the associated `default` value.
- `allow`, will then check the tag keys against any patterns (if no patterns are set for `allow`, it defaults to allowing all), if a key fails to match a pattern it will be marked for removal.
- `remove`, finally will collate any tags matching the `remove` patterns, with tag keys that were replaced by the `update` and marked for `removal` in the `allow` step and establish a complete list of tags to be removed.

The below example shows the following behavior:
- `update` will perform common corrections to consolidate typos and old standards of keys to new keys, to ensure we use `env` and `cost_center` where any of the patterns are matched.
- `require` will then ensure every S3 bucket has the `env`, `owner` and `cost_center` tags, for example if a bucket didn't have an `owner` tag, it would be applied with the `default_owner` value.
- `allow` will then ensure that the patterns provided are the only allowed tags and mark others for removal, in this instance `env`, `owner`, `cost_center` or any beginning with `turbot`.
- `remove` has been left empty as we've used `allow` which is a much more restrictive type, ideally you would only use one of these.

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
    env         = ["~*:^environment$", "~*:^env$", "enviroment"]
    cost_center = ["~*:^cc$","~*:^cost_cent(er|re)$", "~*:^costcent(er|re)$"]
  }
}
```

```sh
flowpipe pipeline run detect_and_correct_s3_buckets_with_incorrect_tag_values --var-file=keys.fpvars
```

#### Combining Value Rules

Again, similarly to the key rules, you can combine the value rules together to create a more complex rule set.

In a similar fashion to the key rules, the first to be applied are the `update` corrections.

Once these corrections are taken into account, any values that match patterns of `remove` or do not match a pattern in `allow` are then amended to be the value default as `default`.

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
-->
## Open Source & Contributing

This repository is published under the [Apache 2.0 license](https://www.apache.org/licenses/LICENSE-2.0). Please see our [code of conduct](https://github.com/turbot/.github/blob/main/CODE_OF_CONDUCT.md). We look forward to collaborating with you!

[Flowpipe](https://flowpipe.io) and [Steampipe](https://steampipe.io) are products produced from this open source software, exclusively by [Turbot HQ, Inc](https://turbot.com). They are distributed under our commercial terms. Others are allowed to make their own distribution of the software, but cannot use any of the Turbot trademarks, cloud services, etc. You can learn more in our [Open Source FAQ](https://turbot.com/open-source).

## Get Involved

**[Join #flowpipe on Slack →](https://turbot.com/community/join)**

Want to help but don't know where to start? Pick up one of the `help wanted` issues:

- [Flowpipe](https://github.com/turbot/flowpipe/labels/help%20wanted)
- [AWS Tags Mod](https://github.com/turbot/flowpipe-mod-aws-tags/labels/help%20wanted)