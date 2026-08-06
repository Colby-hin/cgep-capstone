package main

import rego.v1

iam_metadata := {
	"framework": "HIPAA Security Rule",
	"control_id": "164.312(a)(1)",
	"gap": "GAP-07",
	"severity": "high",
	"remediation": "Replace wildcard data-store permissions with scoped DynamoDB, S3, and KMS actions and resource ARNs.",
}

iam_policy := policy if {
	policy := json_policy("aws_iam_role_policy.lambda_inline")
}

iam_allow_action(action) if {
	policy := iam_policy
	some statement in object.get(policy, "Statement", [])
	upper(object.get(statement, "Effect", "")) == "ALLOW"
	action in statement_actions(statement)
}

iam_broad_data_action if {
	iam_allow_action("*")
}

iam_broad_data_action if {
	iam_allow_action("dynamodb:*")
}

iam_broad_data_action if {
	iam_allow_action("s3:*")
}

iam_required_action_unscoped if {
	policy := iam_policy
	some statement in object.get(policy, "Statement", [])
	upper(object.get(statement, "Effect", "")) == "ALLOW"

	some action in statement_actions(statement)
	action in {"dynamodb:PutItem", "s3:PutObject"}

	"*" in statement_resources(statement)
}

iam_required_actions_present if {
	iam_allow_action("dynamodb:PutItem")
	iam_allow_action("s3:PutObject")
}

iam_least_privilege_compliant if {
	iam_required_actions_present
	not iam_broad_data_action
	not iam_required_action_unscoped
}

iam_least_privilege_deny contains message if {
	not iam_least_privilege_compliant

	message := sprintf(
		"[%s %s][%s][severity=%s] Lambda IAM data access is not least privilege. Remediation: %s",
		[
			iam_metadata.framework,
			iam_metadata.control_id,
			iam_metadata.gap,
			iam_metadata.severity,
			iam_metadata.remediation,
		],
	)
}

deny contains message if {
	message := iam_least_privilege_deny[_]
}
