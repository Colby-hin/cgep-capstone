package main

import rego.v1

s3_tls_pass_policy := {
	"Version": "2012-10-17",
	"Statement": [{
		"Sid": "DenyInsecureTransport",
		"Effect": "Deny",
		"Principal": "*",
		"Action": "s3:*",
		"Resource": [
			"arn:aws:s3:::example",
			"arn:aws:s3:::example/*",
		],
		"Condition": {"Bool": {"aws:SecureTransport": "false"}},
	}],
}

s3_tls_fail_policy := {
	"Version": "2012-10-17",
	"Statement": [],
}

s3_tls_pass_plan := {"resource_changes": [{
	"address": "aws_s3_bucket_policy.uploads_tls",
	"change": {
		"actions": ["create"],
		"after": {"policy": json.marshal(s3_tls_pass_policy)},
	},
}]}

s3_tls_fail_plan := {"resource_changes": [{
	"address": "aws_s3_bucket_policy.uploads_tls",
	"change": {
		"actions": ["create"],
		"after": {"policy": json.marshal(s3_tls_fail_policy)},
	},
}]}

test_s3_tls_pass if {
	result := s3_tls_deny with input as s3_tls_pass_plan
	count(result) == 0
}

test_s3_tls_fail if {
	result := s3_tls_deny with input as s3_tls_fail_plan
	count(result) == 1

	some message in result
	contains(message, "164.312(e)(1)")
	contains(message, "GAP-03")
}
