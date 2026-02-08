# LQS-IoT Downlink Architecture

## Design Principles & Device Classification (Authoritative)

### 1. Purpose

This document defines the top-level design principles and non-negotiable constraints for FIWARE's role in **downlink interactions** within the system, and provides a clear, deterministic device classification model to determine:

- Which devices **may** receive downlink interactions through FIWARE
- Which devices **must not** receive any downlink interactions through FIWARE

This document is the **Architecture Constitution**. All subsequent implementations, deployments, tooling choices, and security design must not violate its provisions.

---

### 2. Normative Definitions

| Term | Definition |
|------|------------|
| **Context Plane** | The system layer responsible for describing, synchronising, and integrating "world state". Characteristics include: retriable, delayable, observable. |
| **Control Plane** | The system layer responsible for conveying control requests with "execution semantics", including but not limited to: authorisation, verification, ordering, exactly-once, expiry, and safety guarantees. |
| **Downlink Interaction** | Any information passed from the platform toward a device, whether called command, request, or intent. In FIWARE, the IoT Agent uses `command` as the attribute type; the payload must still comply with Intent semantics as defined in this document. |
| **Context Writer** | Any entity that can write to Context (e.g. Orion entity / attribute). |

---

### 3. Non-Negotiable Principles

The following principles are **MUST** clauses. Any design that cannot satisfy any one of them is considered an architecture violation.

#### P1. FIWARE Must Not Be the Control Authority

FIWARE is not responsible for, and must not be expected to:

- Decide whether an action "should be executed"
- Provide execution ordering, exactly-once, expiry, or other control semantics
- Bear any safety-critical or risk-control responsibility

If a device or scenario requires any of the above, FIWARE must not be used as its downlink channel.

#### P2. Context Plane and Control Plane Must Be Strictly Separated

- **Context Plane** describes *what is* / *what was*
- **Control Plane** handles *what should happen*

FIWARE belongs only to the Context Plane and must not simultaneously bear the responsibility for conveying and executing control requests.

#### P3. Device Is Never a Context Writer

- A device must not directly call Orion or any Context Write API
- A device must not hold credentials or privileges that represent a Context Writer
- Context writes may only be performed by trusted service roles on behalf of the device

**Gateway/Edge Service clarification**: An edge gateway (e.g. Yardmaster) that proxies between physical devices and the platform is a *trusted service*, not the device itself. The gateway may send device measurements/status to the IoT Agent; the **Agent** is the Context Writer (it interprets device payload and writes to Orion). The device/gateway does not directly write to Orion. This satisfies P3.

#### P4. FIWARE Downlink May Only Express "Intent", Not "Action"

FIWARE downlink interactions **may only** express:

- Desired state
- Preferences
- Best-effort (non-real-time) requests — no hard deadline; the device may execute when it can

FIWARE downlink interactions **must not** express:

- Immediately executable actions — i.e. actions with real-time or bounded-latency constraints
- Control semantics such as start/stop, trigger, switch, reset — i.e. imperative commands that must be carried out within a specified time window

**Intent vs Action boundary**: If the downlink can be phrased as "desired state X" (the device converges when it can) rather than "do X within N ms", it is Intent. If execution timing or ordering is safety- or correctness-critical, it is Action and must use the Control Plane.

#### P5. Device Must Retain Final Discretion

- All FIWARE downlink interactions are treated as non-authoritative
- The device may refuse, ignore, or defer processing
- Refusal or ignorance must not lead to safety issues or system failure

#### P6. All Context Write Behaviour Must Be Traceable

Every Context write must be able to answer:

- Which service identity performed it
- At what time it was performed
- Which entity / attribute / value was written

#### P7. No Unattended Closed-Loop Control

- **Prohibited**: subscription → automatic write-back of downlink interaction
- FIWARE subscriptions may only be used for notifications, alerts, or decision support
- Writing downlink intents must pass through an explicit responsibility boundary (human or service decision)

---

### 4. Why Classify by "Device" Rather Than "Command"

- Command semantics may evolve with requirements
- Device capability and risk attributes are relatively stable

Therefore: **Whether a device may receive downlink interactions through FIWARE must be determined by the device's attributes, not by the description of a single command.**

---

### 5. Device Classification Model

This architecture defines two, and only two, device classifications:

1. **Intent-Only Device**
2. **Control-Semantic Device**

Every device **must** belong to exactly one of these classes.

---

### 6. Intent-Only Device (FIWARE-Eligible)

#### 6.1 Definition

An **Intent-Only Device** is one that may receive downlink interactions through FIWARE, where such interactions serve only as non-authoritative intent. Even if misused, replayed, delayed, or ignored, they do not cause physical risk or irreversible system consequences.

#### 6.2 Required Conditions (All MUST Be True)

| ID | Condition |
|----|-----------|
| I-1 | **No hazardous or mechanical actuation** — Does not move, apply force, or start/stop machinery; does not switch or release hazardous energy (high voltage, heat, pressure). *Excluded from this prohibition*: low-power displays and indicators (e.g. LED strips, signage screens) that emit light only and pose no physical risk. |
| I-2 | **Downlink can be safely ignored** — Even if downlink content is never executed, no safety or system issues arise |
| I-3 | **No control semantics required** — No replay protection; no ordering, expiry, or exactly-once guarantees |
| I-4 | **Downlink can be modelled as desired state** — Describes "what state we wish to be in", not "what to do immediately" |
| I-5 | **Device has final refusal capability** — The device may refuse or defer processing of downlink intent based on its own state |

#### 6.3 Quick Decision Table

**Evaluation order**: Check rows 1–3 first. If any answer matches the "Control-Semantic" column, the device is Control-Semantic. Only if all three pass, check row 4 to confirm Intent-Only. **Fallback**: If the classification is unclear, default to Control-Semantic.

| Question | If the answer is… | Classification |
|----------|-------------------|----------------|
| Can the downlink be safely ignored? | No | Control-Semantic |
| Is replay / ordering / expiry required? | Yes | Control-Semantic |
| Does it cause physical motion or hazardous energy switching? | Yes | Control-Semantic |
| (All above pass) Is the downlink merely desired state? | Yes | Intent-Only |

---

### 7. Control-Semantic Device (FIWARE-Prohibited)

#### 7.1 Definition

A **Control-Semantic Device** is any device that requires explicit control semantics, actuation capability, or safety guarantees. Such a device **must not** receive any downlink interaction through FIWARE.

#### 7.2 Mandatory Rules

- **Prohibited** from using FIWARE as its downlink channel
- All downlink control must go through a dedicated Control Plane
- FIWARE may only receive its **actual state** (result), not act as the control channel

---

### 8. Classification Governance Rules

- Each device type must be explicitly assigned a classification at design time
- Any change in device capability (e.g. new actuation) requires reclassification
- "Temporarily using as Intent-Only" is not permitted
