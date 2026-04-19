"""
Minimal OTLP/HTTP logs emitter. Reads OTEL_RESOURCE_ATTRIBUTES from the
environment, builds a single log record, and POSTs it to
OTEL_EXPORTER_OTLP_ENDPOINT/v1/logs. No third-party dependencies — stdlib only.

This exists to prove that an env var set by Inspect when launching a sandbox
process is read as expected by an OTLP emitter running inside the sandbox,
and that the resulting resource attributes reach the host collector intact.
"""
import json
import os
import sys
import time
import urllib.request


def parse_otel_resource_attributes(raw: str) -> list[dict]:
    attrs = []
    for kv in raw.split(","):
        kv = kv.strip()
        if not kv or "=" not in kv:
            continue
        key, value = kv.split("=", 1)
        attrs.append({"key": key.strip(), "value": {"stringValue": value.strip()}})
    return attrs


def main() -> int:
    raw_attrs = os.environ.get("OTEL_RESOURCE_ATTRIBUTES", "")
    endpoint = os.environ.get(
        "OTEL_EXPORTER_OTLP_ENDPOINT", "http://host.docker.internal:4318"
    )

    attrs = parse_otel_resource_attributes(raw_attrs)
    if not attrs:
        print("ERROR: OTEL_RESOURCE_ATTRIBUTES produced no attributes", file=sys.stderr)
        return 2

    payload = {
        "resourceLogs": [
            {
                "resource": {"attributes": attrs},
                "scopeLogs": [
                    {
                        "scope": {"name": "d0-sandbox-spike-emit"},
                        "logRecords": [
                            {
                                "timeUnixNano": str(int(time.time() * 1e9)),
                                "severityText": "INFO",
                                "body": {"stringValue": "sandbox emit ok"},
                            }
                        ],
                    }
                ],
            }
        ]
    }

    url = endpoint.rstrip("/") + "/v1/logs"
    body = json.dumps(payload).encode()
    req = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            status = resp.status
            reply = resp.read().decode()
    except Exception as exc:
        print(f"ERROR: POST to {url} failed: {exc}", file=sys.stderr)
        return 1

    print(f"endpoint={url}")
    print(f"http_status={status}")
    print(f"response_body={reply[:200]}")
    print(f"resource_attributes={raw_attrs}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
