package main

import rego.v1

dynamodb_kms_pass_plan := {"resource_changes": [{
	"address": "aws_dynamodb_table.intake",
	"change": {
		"actions": ["update"],
		"after": {"server_side_encryption": [{
			"enabled": true,
			"kms_key_arn": "arn:aws:kms:us-east-1:111122223333:key/example",
		}]},
	},
}]}

dynamodb_kms_fail_plan := {"resource_changes": [{
	"address": "aws_dynamodb_table.intake",
	"change": {
		"actions": ["no-op"],
		"after": {"server_side_encryption": []},
	},
}]}

test_dynamodb_kms_pass if {
	result := dynamodb_kms_deny with input as dynamodb_kms_pass_plan
	count(result) == 0
}

test_dynamodb_kms_fail if {
	result := dynamodb_kms_deny with input as dynamodb_kms_fail_plan
	count(result) == 1

	some message in result
	contains(message, "164.312(a)(2)(iv)")
	contains(message, "GAP-02")
}
