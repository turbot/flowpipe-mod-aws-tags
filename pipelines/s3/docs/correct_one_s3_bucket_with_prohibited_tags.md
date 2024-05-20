# Correct one S3 bucket with prohibited tags

## Overview

Prohibited tags may contain sensitive, confidential, or otherwise unwanted data and should be removed.

This pipeline allows you to specify a single S3 bucket which has prohibited tags and then either send a notification or attempt to perform a predefined corrective action (i.e. removal of the tags).

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_s3_buckets_with_prohibited_tags pipeline](https://hub.flowpipe.io/mods/turbot/aws_tags/pipelines/aws_tags.pipeline.correct_s3_buckets_with_prohibited_tags).