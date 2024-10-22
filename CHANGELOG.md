## v1.0.0 (2024-10-22)

_Breaking changes_

- Flowpipe `v1.0.0` is now required. For a full list of CLI changes, please see the [Flowpipe v1.0.0 CHANGELOG](https://flowpipe.io/changelog/flowpipe-cli-v1-0-0).
- In Flowpipe configuration files (`.fpc`), `credential` and `credential_import` resources have been renamed to `connection` and `connection_import` respectively.
- Renamed all `cred` params to `conn` and updated their types from `string` to `conn`.

_Enhancements_

- Added `library` to the mod's categories.
- Updated the following pipeline tags:
  - `type = "featured"` to `recommended = "true"`
  - `type = "test"` to `folder = "Tests"`

## v0.2.0 [2024-08-21]

_Enhancements_

- Added a default value for the `base_tag_rules` variable. ([#28](https://github.com/turbot/flowpipe-mod-aws-tags/pull/28))

## v0.1.0 [2024-07-24]

_What's new?_

- Detect and correct misconfigured tags across 65+ AWS resource types.
- Automatically add mandatory tags (e.g. `env`, `owner`).
- Clean up prohibited tags (e.g. `secret`, `key`).
- Reconcile shorthand or misspelled tag keys to standardized keys (e.g. `cc` to `cost_center`).
- Update tag values to conform to expected standards, ensuring consistency (e.g. `Prod` to `prod`).

For detailed usage information and a full list of pipelines, please see [AWS Tags Mod](https://hub.flowpipe.io/mods/turbot/aws_tags).
