# Correct S3 buckets with prohibited tags

## Overview

Prohibited tags may contain sensitive, confidential, or otherwise unwanted data and should be removed.

This pipeline allows you to specify a collection of S3 buckets which have prohibited tags and then either send notifications or attempt to perform a predefined corrective action (i.e. removal of the tags) upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_s3_buckets_with_prohibited_tags pipeline](https://hub.flowpipe.io/mods/turbot/aws_tags/pipelines/aws_tags.pipeline.detect_and_correct_s3_buckets_with_prohibited_tags)
- [detect_and_correct_s3_buckets_with_prohibited_tags trigger](https://hub.flowpipe.io/mods/turbot/aws_tags/triggers/aws_tags.trigger.query.detect_and_correct_s3_buckets_with_prohibited_tags)