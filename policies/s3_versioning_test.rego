package main

import rego.v1

s3_versioning_pass_plan := {
	"resource_changes": [
		{
			"address": "aws_s3_bucket_versioning.uploads",
			"change": {
				"actions": ["create"],
				"after": {
					"versioning_configuration": [
						{
							"status": "Enabled",
						},
					],
				},
			},
		},
	],
}

s3_versioning_fail_plan := {
	"resource_changes": [
		{
			"address": "aws_s3_bucket_versioning.uploads",
			"change": {
				"actions": ["create"],
				"after": {
					"versioning_configuration": [
						{
							"status": "Suspended",
						},
					],
				},
			},
		},
	],
}

test_s3_versioning_pass if {
	result := s3_versioning_deny with input as s3_versioning_pass_plan
	count(result) == 0
}

test_s3_versioning_fail if {
	result := s3_versioning_deny with input as s3_versioning_fail_plan
	count(result) == 1

	some message in result
	contains(message, "164.308(a)(7)")
	contains(message, "GAP-04")
}
