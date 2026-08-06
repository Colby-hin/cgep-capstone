package main

import rego.v1

s3_tls_metadata := {
	"framework": "HIPAA Security Rule",
	"control_id": "164.312(e)(1)",
	"gap": "GAP-03",
	"severity": "high",
	"remediation": "Attach a bucket policy that denies all S3 actions when aws:SecureTransport is false.",
}

s3_tls_compliant if {
	policy := json_policy("aws_s3_bucket_policy.uploads_tls")

	some statement in object.get(policy, "Statement", [])

	upper(object.get(statement, "Effect", "")) == "DENY"
	value_contains(object.get(statement, "Action", []), "s3:*")

	condition := object.get(statement, "Condition", {})
	bool_condition := object.get(condition, "Bool", {})

	lower(sprintf("%v", [
		object.get(bool_condition, "aws:SecureTransport", ""),
	])) == "false"
}

s3_tls_deny contains message if {
	not s3_tls_compliant

	message := sprintf(
		"[%s %s][%s][severity=%s] Uploads bucket must deny non-TLS requests. Remediation: %s",
		[
			s3_tls_metadata.framework,
			s3_tls_metadata.control_id,
			s3_tls_metadata.gap,
			s3_tls_metadata.severity,
			s3_tls_metadata.remediation,
		],
	)
}

deny contains message if {
	message := s3_tls_deny[_]
}
