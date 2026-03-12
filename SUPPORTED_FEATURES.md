# Supported Features

## Human-Readable Matrix

| Surface | Status | Notes |
| --- | --- | --- |
| Status list construction | Supported | `new/1` / `new_status_list/1` enforce the Recommendation minimum bit length and support `statusSize`, `statusMessages`, `statusReference`, and `ttl` |
| Index allocation | Supported | Stable monotonic allocation until the list is full |
| Revocation mutation | Supported | `revoke/2` remains a convenience wrapper for single-bit lists |
| Generic status mutation | Supported | `put_status/3` supports multi-bit status values |
| Entry generation | Supported | `build_entry/3` validates `BitstringStatusListEntry` semantics; `entry/3` is the convenience wrapper |
| Entry index parsing | Supported | Stable `{:ok, index}` or error atoms |
| Encode/decode | Supported | Multibase base64url of a GZIP-compressed bitstring, per the Recommendation |
| Status resolution from decoded list | Supported | `resolve_status/2` with `status_from_entry/2` as the compatibility helper |
| Status resolution from credential | Supported | `resolve_status/2`, `status_from_credential/2`, and `from_credential/1` |
| Message-purpose status lists | Supported | `statusPurpose: "message"` with `statusSize` / `statusMessages` |
| Refresh and suspension purposes | Supported | Purpose validation allows Recommendation-defined values |
| Generic VC envelope validation | Out of scope | Lives in `ex_vc` |
| Cryptographic proof verification | Out of scope | Lives in `ex_vc` / caller |

## Machine-Readable Matrix

```json
{
  "status_list": {
    "construction": "supported",
    "allocation": "supported",
    "encoding": "supported",
    "credential_round_trip": "supported",
    "entry_verification": "supported",
    "message_purpose": "supported"
  },
  "out_of_scope": {
    "vc_validation": true,
    "proof_verification": true,
    "did_resolution": true
  }
}
```
