package main

import rego.v1

s3_versioning_metadata := {
	"framework": "HIPAA Security Rule",
	"control_id": "164.308(a)(7)",
	"gap": "GAP-04",
	"severity": "medium",
	"remediation": "Enable S3 versioning on the patient uploads bucket.",
}

s3_versioning_compliant if {
	after := resource_after("aws_s3_bucket_versioning.uploads")

	some configuration in object.get(
		after,
		"versioning_configuration",
		[],
	)

	upper(object.get(configuration, "status", "")) == "ENABLED"
}

s3_versioning_deny contains message if {
	not s3_versioning_compliant

	message := sprintf(
		"[%s %s][%s][severity=%s] Uploads bucket versioning must be enabled. Remediation: %s",
		[
			s3_versioning_metadata.framework,
			s3_versioning_metadata.control_id,
			s3_versioning_metadata.gap,
			s3_versioning_metadata.severity,
			s3_versioning_metadata.remediation,
		],
	)
}

deny contains message if {
	message := s3_versioning_deny[_]
}
