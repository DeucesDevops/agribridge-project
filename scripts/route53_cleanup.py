#!/usr/bin/env python3
"""Delete ExternalDNS A and TXT records so the hosted zone can be removed.

ACM validation CNAMEs are left for Terraform. The zone apex NS and SOA stay.
"""

import json
import subprocess
import sys

DELETE_TYPES = {"A", "AAAA", "TXT"}
RECORD_KEYS = {
    "Name",
    "Type",
    "TTL",
    "ResourceRecords",
    "AliasTarget",
    "SetIdentifier",
    "Weight",
    "Region",
    "Failover",
    "MultiValueAnswer",
    "GeoLocation",
    "HealthCheckId",
}


def slim(record):
    return {key: value for key, value in record.items() if key in RECORD_KEYS}


def changes_for(records, zone_name):
    apex = zone_name.rstrip(".") + "."
    changes = []
    for record in records:
        name = record.get("Name", "")
        if record.get("Type") in {"NS", "SOA"} and name == apex:
            continue
        if record.get("Type") not in DELETE_TYPES:
            continue
        changes.append({"Action": "DELETE", "ResourceRecordSet": slim(record)})
    return changes


def main(argv):
    if len(argv) < 2:
        print("usage: route53_cleanup.py ZONE_ID [--apply]", file=sys.stderr)
        return 2
    zone_id = argv[1]
    apply = "--apply" in argv[2:]
    listed = subprocess.run(
        [
            "aws", "route53", "list-resource-record-sets",
            "--hosted-zone-id", zone_id, "--output", "json",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    payload = json.loads(listed.stdout)
    zone = subprocess.run(
        ["aws", "route53", "get-hosted-zone", "--id", zone_id, "--output", "json"],
        check=True,
        capture_output=True,
        text=True,
    )
    zone_name = json.loads(zone.stdout)["HostedZone"]["Name"]
    changes = changes_for(payload.get("ResourceRecordSets", []), zone_name)
    if not changes:
        print("No ExternalDNS records to delete.")
        return 0
    print(f"{len(changes)} record(s) to delete.")
    if not apply:
        print("Pass --apply to delete them.")
        return 0
    for start in range(0, len(changes), 100):
        batch = {"Changes": changes[start:start + 100]}
        subprocess.run(
            [
                "aws", "route53", "change-resource-record-sets",
                "--hosted-zone-id", zone_id,
                "--change-batch", json.dumps(batch),
            ],
            check=True,
        )
    print("Deleted.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
