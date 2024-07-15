# AWS Tags mod for Flowpipe

Pipelines to detect and correct AWS resource tag keys and values based on a provided ruleset.

## Documentation

- **[Hub →](https://hub.flowpipe.io/mods/turbot/aws_tags)**

## Getting Started

### Requirements

Docker daemon must be installed and running. Please see [Install Docker Engine](https://docs.docker.com/engine/install/) for more information.

### Installation

Download and install [Flowpipe](https://flowpipe.io/downloads) and [Steampipe](https://steampipe.io/downloads). Or use Brew:

```sh
brew install turbot/tap/flowpipe
brew install turbot/tap/steampipe
```

Install the AWS plugin with [Steampipe](https://steampipe.io):

```sh
steampipe plugin install aws
```

Steampipe will automatically use your default AWS credentials. Optionally, you can [setup multiple accounts](https://hub.steampipe.io/plugins/turbot/aws#multi-account-connections) or [customize AWS credentials](https://hub.steampipe.io/plugins/turbot/aws#configuring-aws-credentials).

Create a [`credential_import`](https://flowpipe.io/docs/reference/config-files/credential_import) resource to import your Steampipe AWS connections:

```sh
vi ~/.flowpipe/config/aws.fpc
```

```hcl
credential_import "aws" {
  source      = "~/.steampipe/config/aws.spc"
  connections = ["*"]
}
```

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

To start using this mod, you may need to configure some [input variables](https://flowpipe.io/docs/build/mod-variables#input-variables).

The simplest way to do this is to copy the example file `tags.fpvars.example` to `tags.fpvars`, and then update the values as needed. Alternatively, you can pass the variables directly via the command line or environment variables. For more details on these methods, see [passing input variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables).

```sh
cp tags.fpvars.example tags.fpvars
vi tags.fpvars
```

Whilst most [variables](https://hub.flowpipe.io/mods/turbot/aws_tags/variables)

### Configuring Tag Rules

The `base_tag_rules` variable is an object defined as below. It allows you to specify how tags should be managed on your resources. Let's break down each attribute and how you can configure it for specific use cases.

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

If you require all your resources to have a set of predefined tags, you can use the `add` attribute to apply these tags to resources that currently do not have the desired tags, along with a default value.

Let's say we want to ensure every resource has the `environment` and `owner` tags. We could write this rule as:

```hcl
base_tag_rules = {
  add = {
    environment = "unknown"
    owner       = "turbie"
  }
}
```

Here, the map key is the tag you want to ensure exists on your resources, and the value is the default value to apply.

#### Remove: Ensuring Resources Don't Have Prohibited Tags 

Over time, tags can accumulate on your resources for various reasons. You can use the `remove` attribute to clean up tags that are no longer wanted or allowed from your resources.

If we wanted to ensure that we didn't include `password`, `secret` or `key` tags on our resources, we could write this rule as:

```hcl
base_tag_rules = {
  remove = ["password", "secret", "key"]
}
```

However, the above will only cater to exact matches on those strings. This means we may miss tags like `Password` or `ssh_key` as these tags are in a different casing or contain extraneous characters. To achieve better matching we can use patterns along with [supported operators](#supported-operators) in the format `operator:pattern`.

This would allow us to write rules which match more realistic cirumstances and remove tags that contain `password`, begin with `secret`, or end with `key` regardless of the casing.

```hcl
base_tag_rules = {
  remove = ["~*:password", "ilike:secret%", "~*:key$"]
}
```

This allows us to remove any tags which match any of the defined patterns.

#### Remove Except: Ensuring Resources Only Have Permitted Tags

Another approach to cleaning up your tags is to ensure that you only keep those that are desired or permitted and remove all others. You can use the `remove_except` attribute to define a list of patterns for retaining matching tags, while all other tags are removed.

Since this is the inverse behavior of `remove`, it's best to use one or the other to avoid conflicts. Both follow the same `operator:pattern` matching behavior.

Lets say we want to ensure our resources **only** have the following tags:
- `environment`
- `owner`
- `cost_center`
- Any that are prefixed with our company name `turbot`

We can write this rule as:

```hcl
base_tag_rules = {
  remove_except = ["environment", "owner", "cost_center", "~:^turbot"]
}
```

Any tags which do not match one of the above patterns will be removed from the resources.

#### Update Keys: Ensuring Tag Keys Are Standardized

Over time your tagging standards may change, or you may have variants of the same tag that you wish to standardize. You can use the `update_keys` attribute to reconcile tags to a standardized set.

Previously, we may have used shorthand tags like `env` or `cc` which we want to reconcile to our new standard `environment` and `cost_center`. We may also have encountered common spelling errors such as `enviroment` or `cost_centre`. To standardize these tags, we can write the rule as:

```hcl
base_tag_rules = {
  update_keys = {
    environment = ["env", "ilike:enviro%"]
    cost_center = ["~*:^cc$", "~*:^cost_cent(er|re)$", "~*:^costcent(er|re)$"]
  }
}
```

Behind the scenes, this works by creating a new tag with the value of existing matched tag and then removing the existing matched tag.

#### Update Values: Ensuring Tag Values Are Standardized

Just like keys, you may want to standardize the values over time or correct common typos. You can use the `update_values` attribute to reconcile values to expected standards.

This works in a similar way to `update_keys` but has an extra layer of nesting to group the updates on a per-key basis. The outer map key is the tag key, the inner map key is the new value, and the patterns are used for matching the existing values.

Previously, we may have used shorthand or aliases for tag values that we now want to standardize. For instance:
- For the `environment` tag, any previous shorthand or aliases should be standardized to the full names.
- For the `cost_center` tag, any values containing non-numeric characters should be replaced by a default cost center.
- For the `owner` tag, any resources previously owned by _nathan_ or _Dave_ should now be owned by _bob_.

Let's write these rules as follows:

```hcl
base_tag_rules = {
  update_values = {
    environment = {
      production        = ["~*:^prod"]
      test              = ["~*:^test", "~*:^uat$"]
      quality_assurance = ["~*:^qa$", "ilike:%qual%"]
      development       = ["~*:^dev"]
    }
    cost_center = {
      "0123456789" = ["~:[^0-9]"]
    }
    owner = {
      bob = ["~*:^nathan$", "ilike:Dave"]
    }
  }
}
```

Additionally, for a given key we can specify a default to use for the tags value when no other patterns match using a special `else:` operator. This is especially useful when you want to ensure that all values are updated to a standard without knowing all potential matches.

Let's say that we want any `environment` with a value not matching our patterns for `production`, `test` or `quality_assurance` to default to `development`. We could rewrite our rule as below:

```hcl
base_tag_rules = {
  update_values = {
    environment = {
      production        = ["~*:^prod"]
      test              = ["~*:^test", "~*:^uat$"]
      quality_assurance = ["~*:^qa$", "ilike:%qual%"]
      development       = ["else:"]
    }
    cost_center = {
      "0123456789" = ["~:[^0-9]"]
    }
    owner = {
      bob = ["~*:^nathan$", "ilike:Dave"]
    }
  }
}
```

> Note: Whilst it is possible to have multiple `else:` patterns declared for any given tag, only the one with the first alphabetically sorted value (inner map key) will be used.

In this configuration:

- The `environment` tag values like `prod`, `qa`, and `uat` will be standardized to `production`, `quality_assurance`, and `test`, respectively. Any unmatched values will default to `development`.
- The `cost_center` tag values that contain non-numeric characters will be replaced with `0123456789`.
- The `owner` tag values `Nathan` and `Dave` will be changed to `bob`.

This approach ensures that all your tag values are consistently updated, even when new or unexpected values are encountered.

#### Complete Tag Rules

Now that you understand each of the attributes available in the `base_tag_rules` object individually, you can combine them to create a complex ruleset for managing your resource tags. By leveraging multiple attributes together you can achieve sophisticated tagging strategies.

> Note: Using `remove` / `remove_except`
>
> Ideally, you should use either the `remove` or the `remove_except` attribute, but not both simultaneously. This ensures clarity in your tag removal logic and avoids potential conflicts.
>
> - `remove`: Use this to specify patterns of tags you want to explicitly remove.
> - `remove_except`: Use this to specify patterns of tags you want to retain, removing all others.

When using a combination of attributes to build a complex ruleset, they will be executed in the following order to ensure logical application of the rules:

1. `update_keys`: Start by updating any incorrect keys to the new expected values.
2. `add`: Add missing mandatory tags with a default value. This is done after updating the keys to ensure that if update has the same tag, the value isn't overwritten with the default but kept.
3. `remove`/`remove_except`: Remove any tags no longer required based on the patterns provided and old tags which have been updated.
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
      bob = ["~*:^nathan$", "ilike:Dave"]
    }
  }
}
```

This ensures that:
- Firstly, the keys are updated, so we can safely perform the next rules on those keys.
- Secondly, any missing required tags are added.
- Thirdly, any tags that are no longer required are removed.
- Finally, the values are updated as required.

#### Resource-Specific Tag Rules

You have three options for defining tag rules:

1. Only provide `base_tag_rules`: Apply the same rules to every resource.
2. Omit `base_tag_rules` and only provide resource-specific rules (e.g. `s3_buckets_tag_rules`): Allow for custom rules per resource.
3. Provide both `base_tag_rules` and resource-specific rules: Merge the rules to create a comprehensive ruleset.

When merging the `base_tag_rules` with resource-specific rules, the following behaviors apply:

- **Maps** (e.g., `add`, `update_keys`, `update_values`): The maps from the resource-specific rules will be merged with the corresponding maps in the `base_tag_rules`. If a key exists in both the base rules and the resource-specific rules, the value from the resource-specific rules will take precedence.
- **Lists** (e.g., `remove`, `remove_except`): The lists from both the base and resource-specific rules will be merged/concatenated and then deduplicated to ensure that all unique entries from both lists are included.

Let's say you have base_tag_rules defined as follows:

```hcl
base_tag_rules = {
  add = {
    environment = "unknown"
    cost_center = "0123456789"
    owner       = "turbie"
  }
  remove = ["~*:password", "ilike:secret%"]
  remove_except = []
  update_keys = {
    environment = ["env", "ilike:enviro%"]
    cost_center = ["cc", "~*:^cost_cent(er|re)$", "~*:^costcent(er|re)$"]
  }
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
      bob = ["~*:^nathan$", "ilike:Dave"]
    }
  }
}
```

And you want to apply additional rules to S3 buckets:

```hcl
s3_bucket_tag_rules = {
  add = {
    resource_type = "bucket"
  }
  remove = ["ilike:secret%", "~*:key$"]
  remove_except = []
  update_keys = {
    environment = ["~*:^env"]
    owner       = ["~*:^owner$", "~*:manager$"]
  }
  update_values = {
    owner = {
      bob = ["~*:^dave$"]
    }
  }
}
```

When merged, the resulting tag rules for S3 buckets will be:

```hcl
{
  add = {
    environment   = "unknown"
    cost_center   = "0123456789"
    owner         = "turbie"
    resource_type = "bucket"
  }
  remove = ["~*:password", "ilike:secret%", "~*:key$"]
  remove_except = []
  update_keys = {
    environment = ["~*:^env"]
    cost_center = ["cc", "~*:^cost_cent(er|re)$", "~*:^costcent(er|re)$"]
    owner       = ["~*:^owner$", "~*:manager$"]
  }
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
      bob = ["~*:^dave$"]
    }
  }
}
```

In this example:

- The `add` map includes entries from both `base_tag_rules` and `s3_bucket_tag_rules`.
- The `remove` list is a concatenation of entries from both lists, ensuring no duplicates (`"ilike:secret%"` appears only once).
- The `remove_except` list remains empty as specified in both rules.
- The `update_keys` map merges entries, with the resource-specific rules for environment and owner overriding the base rules entirely.
- The `update_values` map shows that the resource-specific rule for `owner` overrides the base rule for the same key.

By providing resource-specific tag rules, you can customize and extend the base tagging strategy to meet the unique requirements of individual resources, ensuring flexibility and consistency in your tag management.

#### Supported Operators

The below table shows the currently supported operators for pattern-matching.

| Operator | Purpose |
| -------- | ------- |
| `=`      | Case-sensitive exact match |
| `like`   | Case-sensitive pattern matching, where `%` indicates zero or more characters and `_` indicates a single character. |
| `ilike`  | Case-insensitive pattern matching, where `%` indicates zero or more characters and `_` indicates a single character. |
| `~`      | Case-sensitive pattern matching using `regex` patterns. | 
| `~*`     | Case-insensitive pattern matching using `regex` patterns. | 
| `else:`  | _Special Operator_ only supported in `update_values` to indicate that this value should be used as replacement value if no other pattern is matched. The whole value must be an _exact match_ of `else:` with no trailing information. |

If you attempt to use an operator *not* in the table above, the string will be processed as an exact match.
For example,  `!~:^bob` wouldn't match anything that doesn't begin with `bob`; instead, it would only match if the key/value is exactly `!~:^bob`.

### Running Pipelines

This mod contains a few different types of pipelines:
- `detect_and_correct`: these are the core pipelines intended for use, they will utilise [Steampipe](https://steampipe.io) queries to determine amendments to your tags based on the provided ruleset(s).
- `correct` / `correct_one`: these pipelines are designed to be fed from the `detect_and_correct` pipelines, albeit they've been separated out to allow you to utilise your own detections if desired, this is an advanced use-case however, thus won't be covered in this documentation.
- Other `utility` type pipelines such as `add_and_remove_resource_tags`, these are designed to be used by other pipelines and should only be called directly if you've read and understood the functionality.

Let's begin by looking at how to run a `detect_and_correct` pipeline, assuming you've already followed the [installation instructions](#installation) and [configured tag rules](#configuring-tag-rules) as required


Firstly, we need to ensure that [Steampipe](https://steampipe.io) is running in [service mode](https://steampipe.io/docs/managing/service).

```sh
steampipe service start
```

The pipeline we want to run will be `detect_and_correct_<resource_type>_with_incorrect_tags`, we can find those available by running the following command:

```sh
flowpipe pipeline list | grep "detect_and_correct"
```

Then run your chosen pipeline, for example if we wish to remediate tags on our `S3 buckets`:
```sh
flowpipe pipeline run detect_and_correct_s3_buckets_with_incorrect_tags --var-file tags.fpvars
```

This will then run the pipeline and depending on your configured running mode; perform the relevant action(s), there are 3 running modes:
- Notify Only
- Automatic
- Wizard

#### Notify Only
This is the default `out-of-the-box` behavior, requiring no additional configuration. 

As the name implies, this mode is designed to send a message on your configured [notifier](https://flowpipe.io/docs/reference/config-files/notifier) for each resource that violated a tagging rule along with the suggested remedial action.

#### Automatic
This behavior allows for a hands-off approach to remediating (or ignoring) your tagging ruleset violations.

To run in automatic mode, you can either change the `incorrect_tags_default_action` variable from `notify` to either `skip` or `apply` in your fpvars file

```hcl
# tags.fpvars
incorrect_tags_default_action = "apply"
base_tag_rules = ... # omitted for brevity
```

or pass the `default_action` argument on the command-line.

```sh
flowpipe pipeline run detect_and_correct_s3_buckets_with_incorrect_tags --var-file tags.fpvars --arg='default_action=apply'
```

Valid values are:
- `notify`: This is the default value and is actually [notify only](#notify-only) mode.
- `skip`: This will ignore any detections and not perform any other remediative action.
- `apply`: This will automatically apply the remediative actions to your resources.

To further enhance this approach, you can enable the pipelines corresponding [query trigger](#running-query-triggers) to run completely hands-off.

#### Wizard
If you prefer a more hands-on approach to approving changes to your resources tags, you can run in wizard mode, which will prompt you for input on each resource detected that violates your ruleset.

To run in wizard mode, you can either set the `approvers` variable in your `fpvars` file

```hcl
# tags.fpvars
approvers = ["default"]
base_tag_rules = ... # omitted for brevity
```

or pass the `approvers` argument on the command-line.

```sh
flowpipe pipeline run detect_and_correct_s3_buckets_with_incorrect_tags --var-file tags.fpvars --arg='approvers=["default"]'
```

This will run the pipeline locally, prompting you directly in the terminal to select the action for each detected resource.

You can combine this approch using Flowpipe [server](https://flowpipe.io/docs/run/server) and [external integrations](https://flowpipe.io/docs/build/input) to prompt in `http`, `slack`, `teams`, etc.

### Running Query Triggers

> Note: Query triggers require Flowpipe running in [server](https://flowpipe.io/docs/run/server) mode.

Each `detect_and_correct` pipeline comes with a corresponding [Query Trigger](https://flowpipe.io/docs/flowpipe-hcl/trigger/query), these are _disabled_ by default allowing for you to _enable_ and _schedule_ them as desired.

Let's begin by looking at how to set-up a Query Trigger to automatically resolve tagging violations with our S3 Buckets.

Firsty, we need to update our `tags.fpvars` file to add or update the following variables - if we want to run our remediation `hourly` and automatically `apply` the corrections:

```hcl
# tags.fpvars

s3_buckets_with_incorrect_tags_trigger_enabled   = true
s3_buckets_with_incorrect_tags_trigger_scheduled = "1h"
incorrect_tags_default_action                    = "apply"

base_tag_rules = ... # omitted for brevity
```

Now we'll need to start up our Flowpipe server:

```sh
flowpipe server --var-file=tags.fpvars
```

This will activate every hour and detect S3 buckets with tagging violations and apply the corrections without further interaction!

#### Detection Differences: Query Trigger vs Pipeline

When running the `detect_and_correct` paths, there is a key difference in the detections returned when using a query trigger vs calling the pipeline.

This is due to the query trigger caching the result set, therefore once a resource has been detected, if it is skipped it will not be returned in future detections until the query trigger cache is cleared or the resource is removed by a run of the query trigger where the result is ok.

## Open Source & Contributing

This repository is published under the [Apache 2.0 license](https://www.apache.org/licenses/LICENSE-2.0). Please see our [code of conduct](https://github.com/turbot/.github/blob/main/CODE_OF_CONDUCT.md). We look forward to collaborating with you!

[Flowpipe](https://flowpipe.io) and [Steampipe](https://steampipe.io) are products produced from this open source software, exclusively by [Turbot HQ, Inc](https://turbot.com). They are distributed under our commercial terms. Others are allowed to make their own distribution of the software, but cannot use any of the Turbot trademarks, cloud services, etc. You can learn more in our [Open Source FAQ](https://turbot.com/open-source).

## Get Involved

**[Join #flowpipe on Slack →](https://turbot.com/community/join)**

Want to help but don't know where to start? Pick up one of the `help wanted` issues:

- [Flowpipe](https://github.com/turbot/flowpipe/labels/help%20wanted)
- [AWS Tags Mod](https://github.com/turbot/flowpipe-mod-aws-tags/labels/help%20wanted)