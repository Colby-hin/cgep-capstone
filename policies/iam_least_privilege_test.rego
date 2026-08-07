package main

import rego.v1

iam_pass_policy := {
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": ["dynamodb:PutItem"],
			"Resource": "arn:aws:dynamodb:us-east-1:111122223333:table/intake",
		},
		{
			"Effect": "Allow",
			"Action": ["s3:PutObject"],
			"Resource": "arn:aws:s3:::uploads/*",
		},
		{
			"Effect": "Allow",
			"Action": [
				"kms:Encrypt",
				"kms:Decrypt",
				"kms:GenerateDataKey*",
			],
			"Resource": "arn:aws:kms:us-east-1:111122223333:key/example",
		},
	],
}

iam_fail_policy := {
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": "dynamodb:*",
			"Resource": "*",
		},
		{
			"Effect": "Allow",
			"Action": "s3:*",
			"Resource": "*",
		},
	],
}

iam_pass_plan := {"resource_changes": [{
	"address": "aws_iam_role_policy.lambda_inline",
	"change": {
		"actions": ["update"],
		"after": {"policy": json.marshal(iam_pass_policy)},
	},
}]}

iam_fail_plan := {"resource_changes": [{
	"address": "aws_iam_role_policy.lambda_inline",
	"change": {
		"actions": ["update"],
		"after": {"policy": json.marshal(iam_fail_policy)},
	},
}]}

test_iam_least_privilege_pass if {
	result := iam_least_privilege_deny with input as iam_pass_plan
	count(result) == 0
}

test_iam_least_privilege_fail if {
	result := iam_least_privilege_deny with input as iam_fail_plan
	count(result) == 1

	some message in result
	contains(message, "164.312(a)(1)")
	contains(message, "GAP-07")
}
