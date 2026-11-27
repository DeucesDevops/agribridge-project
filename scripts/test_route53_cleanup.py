import unittest

from route53_cleanup import changes_for


class Route53CleanupTest(unittest.TestCase):
    def test_keeps_apex_ns_and_validation_cnames(self):
        records = [
            {"Name": "agribridge.deuces.dev.", "Type": "NS", "TTL": 172800, "ResourceRecords": [{"Value": "ns-1.awsdns-00.com."}]},
            {"Name": "agribridge.deuces.dev.", "Type": "SOA", "TTL": 900, "ResourceRecords": [{"Value": "ns-1.awsdns-00.com. hostmaster.amazon.com. 1 7200 900 1209600 86400"}]},
            {"Name": "_abc.agribridge.deuces.dev.", "Type": "CNAME", "TTL": 60, "ResourceRecords": [{"Value": "example.acm-validations.aws."}]},
            {
                "Name": "production.agribridge.deuces.dev.",
                "Type": "A",
                "AliasTarget": {"DNSName": "example.elb.amazonaws.com.", "HostedZoneId": "Z1", "EvaluateTargetHealth": False},
            },
            {"Name": "production.agribridge.deuces.dev.", "Type": "TXT", "TTL": 300, "ResourceRecords": [{"Value": "\"heritage=external-dns\""}]},
        ]
        changes = changes_for(records, "agribridge.deuces.dev")
        kinds = [(change["ResourceRecordSet"]["Name"], change["ResourceRecordSet"]["Type"]) for change in changes]
        self.assertEqual(kinds, [
            ("production.agribridge.deuces.dev.", "A"),
            ("production.agribridge.deuces.dev.", "TXT"),
        ])
        self.assertIn("AliasTarget", changes[0]["ResourceRecordSet"])


if __name__ == "__main__":
    unittest.main()
