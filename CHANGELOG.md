## v0.1.0 [2024-07-24]

_What's new?_

- Detect and correct misconfigured tags across 65+ AWS resource types.
- Comprehensive tag management:
  - **Ensure resources have mandatory tags:**
    - Automatically add predefined tags like `environment` and `owner` if they are missing.
  - **Remove prohibited tags:**
    - Clean up tags such as `password`, `secret`, and `key` that are no longer allowed.
  - **Standardize tag keys:**
    - Reconcile shorthand or misspelled tag keys to standardized keys like `environment` and `cost_center`.
  - **Standardize tag values:**
    - Update tag values to conform to expected standards, ensuring consistency.

For detailed usage information and a full list of pipelines, please see [AWS Tags Mod](https://hub.flowpipe.io/mods/turbot/aws_tags).
