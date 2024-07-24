## v0.1.0 [2024-07-24]

_What's new?_

- Detect and correct misconfigured tags across 65+ AWS resource types.
- Automatically add mandatory tags like `environment` and `owner` if they are missing.
- Clean up prohibited tags such as `password`, `secret`, and `key`.
- Reconcile shorthand or misspelled tag keys to standardized keys like `environment` and `cost_center`.
- Update tag values to conform to expected standards, ensuring consistency.

For detailed usage information and a full list of pipelines, please see [AWS Tags Mod](https://hub.flowpipe.io/mods/turbot/aws_tags).
