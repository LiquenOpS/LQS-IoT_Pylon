# Intent-Only Downlink Best-Practice Guidance

**Scope**: The entire downlink path from Orion (Context) to the Device receiving and applying intent.

This document does not restate the definition of Intent-Only. By using this document, you have already confirmed that all your devices are Intent-Only.

---

## 0. The Two Sentences You Must Uphold

> **Intent in Orion is always "desired state", never "command".**

> **No intermediate layer may turn intent into control-semantic behaviour (ordering / expiry / exactly-once / force execute).**

These two sentences are the acceptance criteria for the entire document.

---

## 1. Reference Architecture (Orion → Device Standard Topology)

Typical downlink chains look like this:

### Architecture A: Pull-based (Device/Edge actively pulls) — **Most stable, least likely to drift**

```
Orion (stores desired*)
  ↓ (query / subscription to delivery service)
Downlink Delivery Service (selects targets, rate limits, audit)
  ↓ (device-facing API / broker)
Edge Gateway (optional) (local auth + caching)
  ↓
Device Agent (applies intent best-effort)
```

### Architecture B: Push-based (Platform pushes to edge) — **Viable but easier to misuse as control**

```
Orion
  ↓ (subscription notification)
Downlink Delivery Service
  ↓ (MQTT / HTTP push)
Edge Gateway / Device
```

**Best practice**: In Intent-Only environments, prefer Pull-based. Push-based requires additional guardrails (see below).

#### 1.1 Push-based Guardrails (Required when using Architecture B)

When using Push-based delivery, you must add:

- **Explicit Delivery Service**: Never push directly from Orion subscription to device. The subscription must notify a Delivery Service, which then decides when and whether to push.
- **Rate limiting**: Per-device push frequency cap; do not flood the device with repeated identical updates.
- **No reliability semantics**: Do not use retries, acknowledgements, or "until confirmed" loops that imply guaranteed delivery.
- **Audit**: Log every push (to whom, what version/hash, when).

---

## 2. Orion Layer Best Practices (How to Store Downlink Intent in Orion)

### 2.1 Use `desired*` / `requested*` for intent; never use action verbs

| ✅ Allowed | ❌ Forbidden |
|------------|--------------|
| `desiredDisplayMode = INFO` | `executeNow = true` |
| `requestedConfigVersion = v1.2.3` | `restart = 1` |

### 2.2 Intent must be "comparable", not "executable"

**Best practice**: The device should only need to:

1. Read `desired*`
2. Compare with current `actual*`
3. Apply best-effort if different

### 2.3 Add minimal metadata fields (debounce + audit)

(Intent-Only can use these, but do not introduce control semantics.)

- `desiredConfigHash` (or version) — lets device skip re-apply when unchanged
- `desiredUpdatedAt` (observation only, never as execution deadline)
- `source` (who changed it; for audit)

**Note**: Do not use Orion timestamps as execution deadlines — that leads to control semantics.

**Context modelling**: Model the payload as **desired state** (intent), not imperative command. Avoid lifecycle or transport behaviour that implies execution — e.g. consume-on-ack, clear-after-execute, or any mechanism that ties attribute removal to "the device did it".

---

## 3. Orion → Downlink Delivery Service (The Critical Missing Piece)

The **Downlink Delivery Service** is the most important intermediary in the chain. It is the key to preventing Orion from becoming a control channel.

**FIWARE note**: When using FIWARE, the IoT Agent can fulfill the Delivery Service role only if (a) it is used for notification-driven delivery (Orion subscription → Agent → device callback), and (b) it is not configured or relied upon for reliable delivery guarantees. The Agent must not be positioned as a "command gateway" with execution semantics.

### 3.1 Delivery Service Responsibilities (Must Be Explicitly Defined)

- Read from Orion or receive notifications (subscription)
- Decide which devices to deliver to (targeting)
- Rate limit / batching / backoff
- Audit (who, when, to whom, which version)
- **Must not** guarantee execution; **must not** provide "reliable command delivery" semantics

### 3.2 Orion Subscription Usage (For notification only; not direct control push)

**Best practice**:

- Orion subscription → notifies Delivery Service: "desired* of entity X has changed"
- Delivery Service then decides "when and whether" to deliver

**Anti-pattern (forbidden)**:

- Orion subscription directly targets device endpoint (bypasses Delivery Service)
- Orion subscription triggers an "execute workflow" that forces the device to act

---

## 4. Delivery Service → Edge/Device-facing Channel

Common choices:

### 4.1 MQTT

**Best practice (minimal set)**:

- Topics isolated by device identity: `downlink/<device-id>/desired`
- Broker ACL: device can only subscribe to its own topic
- Payload contains only: entity id, desired fields, version/hash
- Retain: acceptable, but do not rely on it for "guaranteed delivery"

**Anti-pattern**:

- All devices share one topic (e.g. `downlink/all`)
- Device can publish to topics that affect others
- Treating QoS/retain as a "must-execute" guarantee

### 4.2 HTTP (Device pull or gateway push)

**Best practice**:

- Device/Edge gateway pulls periodically: `GET /devices/<id>/desired`
- Use ETag / version / hash to reduce traffic
- Response is a desired state payload only

**Best practice (HTTP push to device)**: If the device receives pushes over HTTP, the endpoint should be named for state receipt (e.g. `PUT /desired` or `POST /desired`) and the payload must be desired state only. The semantics are "here is what we want you to converge to", not "execute this now".

**Anti-pattern**:

- Endpoints named with action verbs: `POST /execute`, `POST /command`, `POST /trigger` — naming suggests imperative execution even when payload is intent; prefer `PUT /desired` or `POST /desired`

---

## 5. Edge Gateway (Optional but Recommended)

If you have many devices, unstable networks, or want an extra governance layer, add an Edge Gateway.

### 5.1 Edge Gateway Best Practices

- Local cache of desired state (device can fetch when offline)
- Local device authentication (device must not face broker/API directly)
- Local throttling (do not repeatedly push same desired to device)
- Local observability via actual state (infer convergence; no explicit delivery ack)

### 5.2 Edge Gateway Prohibitions

- Must not turn intent into a "command queue"
- Must not promise "exactly-once delivery"
- Must not enforce ordering / expiry (leads to control semantics)

---

## 6. Device Agent (Best Practices for Receiving and Applying Intent)

### 6.1 State reconciliation only; no command execution

- Compare desired vs actual
- If different → best-effort converge
- If same → no action

### 6.2 No ack-of-execution

- Do not report "I executed the command"
- Report only actual state
- This keeps the system non-authoritative

### 6.3 Allow replay, delay, and ignore

- Receiving the same desired repeatedly must not accumulate side effects
- Missing a delivery must not be dangerous (this is the Intent-Only premise)

---

## 7. Identity, Credentials, and mTLS

### 7.1 Roles and Certificates (Four distinct types)

| Role | Cert type | Purpose |
|------|-----------|---------|
| Orion / API Server | serverAuth | API server cert |
| Delivery Service | clientAuth | Read Orion; write to delivery channel (or manage broker) |
| Edge Gateway | clientAuth | Connect to Orion or Delivery Service |
| Device | clientAuth | Device ↔ edge/broker only; **must not** write to Orion |

### 7.2 mTLS Segments (Two common segments)

- **S1**: Delivery Service ↔ Orion / API Gateway (mTLS) — Delivery Service authenticates to read Context.
- **S2**: Device-facing channel (mTLS or equivalent strong auth):
  - **Pull**: Edge/Device (client) → Delivery Service or Edge Gateway (server). The device-facing endpoint is the API the device pulls from.
  - **Push**: Delivery Service or Edge (client) → Broker or Edge Gateway (server). If the device receives direct pushes (e.g. MQTT broker), the device authenticates as subscriber; the Broker is the device-facing endpoint.

### 7.3 Certificate Content Examples (Tool-agnostic)

| Role | EKU | SAN URI example |
|------|-----|-----------------|
| Delivery Service | clientAuth | `spiffe://prod/services/downlink-delivery` |
| Edge Gateway | clientAuth | `spiffe://prod/edges/<edge-id>` |
| Device | clientAuth | `spiffe://prod/devices/<device-id>` |

### 7.4 CA and Environment Isolation (Mandatory)

- Different CA per Dev / Test / Prod
- Prod broker/API must never trust non-Prod CA
- This is the most effective way to avoid "test system pushing to production devices"

---

## 8. Network Segmentation and Minimal Exposure

### 8.1 Recommended Zones

- **Intranet zone**: Orion, Delivery Service, Observability
- **IoT zone**: Broker / Edge Gateway, Devices

### 8.2 Minimal Required Connectivity

- IoT zone → Intranet zone: usually no direct path to Orion
- Intranet zone → IoT zone: Delivery Service only connects to broker/gateway on required ports
- Device → broker/gateway: only required ports allowed

---

## 9. Traffic Control and Misuse Prevention

### 9.1 Rate Limit (In Delivery Service or Edge Gateway)

- Per-device update frequency cap (avoid flooding)
- Do not repeatedly push the same desired hash to the same device (proactive pushes); this is traffic optimisation, not semantic restriction
- When the device **pulls**, always return the current desired state — rate limiting applies to outgoing pushes, not pull responses
- Batch large updates (e.g. merge every 5 seconds)

### 9.2 Audit Logging (Mandatory)

Log at least:

- Which Orion entity's desired was changed
- Which devices the Delivery Service delivered to
- Delivered desired version/hash

---

## 10. Forbidden Patterns (End-to-End Anti-Pattern List)

Any of the following indicates that intent-only is being turned into control:

| Anti-pattern | Description |
|--------------|-------------|
| Orion subscription directly targets device endpoint | Bypasses Delivery Service |
| Delivery Service pursues "guaranteed, exactly-once, ordered" semantics | Control semantics |
| Using QoS/retain as a reliable command system | Control semantics |
| Device reports "command success" instead of actual state | Undermines non-authoritative model |
| Device or edge can write Orion desired | Role confusion |
