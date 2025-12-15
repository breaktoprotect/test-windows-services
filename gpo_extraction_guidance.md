# GPO XML Ingestion – Field Extraction Specification

**Scope**
- Group Policy Objects (GPOs) only
- Input format: `Get-GPOReport -ReportType XML`
- Goal: Extract enforceable settings for comparison against CIS Benchmarks and Microsoft OSConfig / Security Baselines
- Audience: Engineers building automated GPO XML parsers and comparison tooling

---

## 0. Guiding Principles

- Extract **atomic settings**, not whole GPOs
- One record = **one enforceable configuration**
- Focus on **deterministic OS state**
- Separate **hardening settings** from **deployment metadata**
- Registry-based policies **must** be extracted for CIS / OSConfig comparison

---

## 1. Global GPO Identity (attach to every extracted record)

Extract once per GPO and attach to all settings.

**Source:** `/GPO/Identifier` and root metadata

- `gpo_id`
  - `/GPO/Identifier/Identifier`
  - GUID string
- `gpo_name`
  - `/GPO/Name`
- `domain`
  - `/GPO/Identifier/Domain`
- `gpo_created_time`
  - `/GPO/CreatedTime`
- `gpo_modified_time`
  - `/GPO/ModifiedTime`

---

## 2. Target Scope

Attach to every extracted setting.

- `scope`
  - Values:
    - `Computer`
    - `User`
  - Determined by:
    - `/GPO/Computer/...`
    - `/GPO/User/...`

> For server and directory service hardening, `Computer` scope is typically primary, but tooling should support both.

---

## 3. Tier-1: Hardening Settings  
**Extract and compare to CIS / Microsoft baselines**

These settings result in **deterministic, inspectable OS state**.

---

### 3.1 Registry-Based Policy (Administrative Templates)

**Purpose**
- Primary comparison surface for CIS and OSConfig
- Declarative and policy-enforced

**XML Location**
- `/GPO/Computer/ExtensionData//q2:RegistrySettings`
- Atomic node: `q2:Registry/q2:Properties`

**Extract per registry value**
- `policy_engine`
  - Constant: `RegistryPolicy`
- `hive`
  - Source: `@hive`
  - Normalize to `HKLM` or `HKCU`
- `registry_key`
  - Source: `@key`
- `value_name`
  - Source: `@name`
- `value_type`
  - Source: `@type`
  - Examples:
    - `REG_DWORD`
    - `REG_SZ`
    - `REG_QWORD`
- `value_raw`
  - Source: `@value`
- `value_decoded`
  - Convert DWORD hex to integer where applicable
- `action`
  - Source: `@action`
  - Values:
    - `C` (Create)
    - `U` (Update)
    - `D` (Delete)
- `setting_key`
  - Canonical format:
    - `Reg::HKLM\<key>\<value_name>`

**Optional (recommended)**
- `item_level_targeting`
  - Serialize `q2:Filters` if present
- `source_xml_path`

---

### 3.2 Advanced Audit Policy

**Purpose**
- Explicitly defined in CIS benchmarks
- Directly comparable and testable

**XML Location**
- `/GPO/Computer/ExtensionData//q1:Audit`

**Extract per audit subcategory**
- `policy_engine`
  - Constant: `AdvancedAuditPolicy`
- `audit_name`
  - `q1:Name`
- `success_enabled`
  - `q1:SuccessAttempts`
- `failure_enabled`
  - `q1:FailureAttempts`
- `setting_key`
  - `Audit::<audit_name>`
- `value`
  - Structure:
    - `{ success: bool, failure: bool }`
- `source_xml_path`

---

### 3.3 User Rights Assignment

**Purpose**
- Explicitly defined in CIS benchmarks
- Controls local and service account privileges

**XML Location**
- `/GPO/Computer/ExtensionData//q1:UserRightsAssignment`

**Extract per privilege**
- `policy_engine`
  - Constant: `UserRightsAssignment`
- `privilege_name`
  - `q1:Name` (e.g. `SeBackupPrivilege`)
- `principals`
  - All `q1:Member/Name`
- `sids`
  - All `q1:Member/SID`
- `setting_key`
  - `UserRights::<privilege_name>`
- `value`
  - List of principals
- `source_xml_path`

---

### 3.4 Security Options (Local Policies)

**Purpose**
- Covers password, Kerberos, SMB, LDAP, and other core security behaviors
- Explicitly defined in CIS benchmarks

**XML Location**
- `/GPO/Computer/ExtensionData//q1:SecurityOption`
  - Often under the `Security` extension

**Extract per option**
- `policy_engine`
  - Constant: `SecurityOptions`
- `option_name`
  - `q1:Name`
- `option_value`
  - `q1:Value`
- `setting_key`
  - `SecOpt::<option_name>`
- `value`
  - Normalize to string, boolean, or integer where possible
- `source_xml_path`

---

## 4. Tier-2: Security-Relevant but Not Baseline-Comparable

Extract for **context only**, not for CIS / OSConfig matching.

---

### 4.1 Scripts (Startup / Shutdown)

**Purpose**
- Can enforce security indirectly
- Not declarative or baseline-comparable

**XML Location**
- `/GPO/Computer/ExtensionData//q1:Scripts/q1:Script`

**Extract**
- `policy_engine`
  - Constant: `Scripts`
- `script_type`
  - `q1:Type` (Startup / Shutdown)
- `command`
  - `q1:Command`
- `run_order`
  - `q1:Order`
- `setting_key`
  - `Script::<script_type>::<command>`
- `source_xml_path`

> Store separately. Do not attempt CIS or OSConfig matching.

---

## 5. Deployment Metadata (Do Not Treat as Hardening)

Extract only if needed for coverage or ownership analysis.

---

### 5.1 GPO Linking

- `links_to`
  - `/GPO/LinksTo/SOMPath`
- `link_enabled`
  - `/GPO/LinksTo/Enabled`
- `enforced`
  - `/GPO/LinksTo/NoOverride` (invert logic)

---

### 5.2 GPO Security (ACLs)

- `SecurityDescriptor`
- `TrusteePermissions`
- `PermissionsPresent`

> These represent GPO governance,сятся, not runtime OS security posture.

---

## 6. Fields to Ignore Entirely

- `VersionDirectory`
- `VersionSysvol`
- `ReadTime`
- `IncludeComments`
- `AuditingPresent`
- UI, display, or image attributes

---

## 7. Minimum Output Record (Recommended)

Each extracted setting record should include:

- `gpo_id`
- `gpo_name`
- `domain`
- `scope`
- `policy_engine`
- `setting_key`
- `value`
- `source_xml_path`

This ensures:
- Reliable CIS / OSConfig comparison
- Audit defensibility
- Clean separation of hardening vs deployment metadata

---

## 8. Implementation Rule (Non-Negotiable)

> If a node does not result in a deterministic, inspectable OS configuration state, it is not a hardening setting.

# Example Output Records

This document provides example output records produced by a GPO XML ingestion pipeline.
Each record represents **one atomic GPO setting** using the universal output fields.

Universal fields:
- gpo_id
- gpo_name
- domain
- scope
- policy_engine
- setting_key
- value
- source_xml_path

---

## Registry-Based Policy (Administrative Templates)

Category:
- Tier-1 hardening
- Deterministic
- Comparable to CIS and Microsoft OSConfig

Example extracted record:
```
{
  "gpo_id": "{A1B2C3D4-1111-2222-3333-ABCDEF123456}",
  "gpo_name": "DC-Hardening-Core",
  "domain": "example.local",
  "scope": "Computer",
  "policy_engine": "RegistryPolicy",
  "setting_key": "Reg::HKLM\\SYSTEM\\CurrentControlSet\\Services\\NTDS\\Parameters\\IntersiteFailuresAllowed",
  "value": 1,
  "source_xml_path": "/GPO/Computer/ExtensionData/RegistrySettings/Registry/Properties[1]"
}
```
---

## Advanced Audit Policy

Category:
- Tier-1 hardening
- Explicitly defined in CIS benchmarks

Example extracted record:
```
{
  "gpo_id": "{A1B2C3D4-1111-2222-3333-ABCDEF123456}",
  "gpo_name": "DC-Audit-Policy",
  "domain": "example.local",
  "scope": "Computer",
  "policy_engine": "AdvancedAuditPolicy",
  "setting_key": "Audit::AuditProcessTracking",
  "value": {
    "success": true,
    "failure": true
  },
  "source_xml_path": "/GPO/Computer/ExtensionData/Audit[4]"
}
```
---

## User Rights Assignment

Category:
- Tier-1 hardening
- Privilege assignments defined in CIS benchmarks

Example extracted record:
```
{
  "gpo_id": "{A1B2C3D4-1111-2222-3333-ABCDEF123456}",
  "gpo_name": "DC-User-Rights",
  "domain": "example.local",
  "scope": "Computer",
  "policy_engine": "UserRightsAssignment",
  "setting_key": "UserRights::SeBackupPrivilege",
  "value": [
    "BUILTIN\\Administrators"
  ],
  "source_xml_path": "/GPO/Computer/ExtensionData/UserRightsAssignment[2]"
}
```
---

## Security Options (Local Policies)

Category:
- Tier-1 hardening
- Authentication and directory security behavior

Example extracted record:
```
{
  "gpo_id": "{A1B2C3D4-1111-2222-3333-ABCDEF123456}",
  "gpo_name": "DC-Security-Options",
  "domain": "example.local",
  "scope": "Computer",
  "policy_engine": "SecurityOptions",
  "setting_key": "SecOpt::Network security: LDAP client signing requirements",
  "value": "Require signing",
  "source_xml_path": "/GPO/Computer/ExtensionData/SecurityOption[7]"
}
```
---

## Scripts (Startup / Shutdown)

Category:
- Tier-2 (contextual)
- Not baseline-comparable

Example extracted record:
```
{
  "gpo_id": "{A1B2C3D4-1111-2222-3333-ABCDEF123456}",
  "gpo_name": "DC-Startup-Scripts",
  "domain": "example.local",
  "scope": "Computer",
  "policy_engine": "Scripts",
  "setting_key": "Script::Startup::Set-SMB1Audit.ps1",
  "value": {
    "type": "Startup",
    "command": "Set-SMB1Audit.ps1",
    "order": 1
  },
  "source_xml_path": "/GPO/Computer/ExtensionData/Scripts/Script[1]"
}
```
---

## Validation Rule

A record is valid if:
- The enforced setting is identifiable via setting_key
- The enforced state is represented in value
- The source XML location is captured in source_xml_path

