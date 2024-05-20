# Detect & correct S3 buckets with prohibited tags

## Overview

Prohibited tags may contain sensitive, confidential, or otherwise unwanted data and should be removed.

This query trigger detects S3 buckets which have prohibited tags and then either sends a notification or attempts to perform a predefined corrective action (i.e. removal of the tags).

## Getting started

By default, this trigger is disabled, however it can be configred by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `s3_buckets_with_prohibited_tags_trigger_enabled` should be set to `true` as the default is `false`.
- `s3_buckets_with_prohibited_tags_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `s3_buckets_with_prohibited_tags_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_prohibited_tags"` to delete any prohibited tags on the resource).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```