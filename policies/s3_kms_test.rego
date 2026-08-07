package main

import rego.v1

s3_kms_pass_plan := {"resource_changes": [{
	"address": "aws_s3_bucket_server_side_encryption_configuration.uploads",
	"change": {
		"actions": ["create"],
		"after": {"rule": [{"apply_server_side_encryption_by_default": [{
			"sse_algorithm": "aws:kms",
			"kms_master_key_id": "arn:aws:kms:us-east-1:111122223333:key/example",
		}]}]},
	},
}]}

s3_kms_fail_plan := {"resource_changes": [{
	"address": "aws_s3_bucket_server_side_encryption_configuration.uploads",
	"change": {
		"actions": ["create"],
		"after": {"rule": [{"apply_server_side_encryption_by_default": [{"sse_algorithm": "AES256"}]}]},
	},
}]}

test_s3_kms_pass if {
	result := s3_kms_deny with input as s3_kms_pass_plan
	count(result) == 0
}

test_s3_kms_fail if {
	result := s3_kms_deny with input as s3_kms_fail_plan
	count(result) == 1

	some message in result
	contains(message, "164.312(a)(2)(iv)")
	contains(message, "GAP-01")
}
