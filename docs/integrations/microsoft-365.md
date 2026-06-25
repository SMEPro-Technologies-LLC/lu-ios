# Microsoft 365 Integration — IOSME

IOSME integrates with **Microsoft 365** to provide calendar access, email notifications, and Teams channel integration for Lamar University users.

---

## Azure AD App Registration

IOSME is registered as an Azure AD (Entra ID) application in the **Lamar University** tenant.

| Field | Value |
|-------|-------|
| Tenant ID | `<AZURE_TENANT_ID>` (stored in `iosme-ms365-oauth` secret) |
| Application (Client) ID | `<AZURE_CLIENT_ID>` |
| App Name | IOSME — Lamar University |
| Supported Account Types | Accounts in this organizational directory only |
| Redirect URI | `https://iosme.lamar.edu/auth/microsoft/callback` |

---

## Permissions (Microsoft Graph API)

| Permission | Type | Purpose |
|------------|------|---------|
| `User.Read` | Delegated | Read signed-in user's profile |
| `Calendars.ReadWrite` | Delegated | Read/write user's calendar (class schedule sync) |
| `Mail.Send` | Delegated | Send notification emails on behalf of user |
| `Team.ReadBasic.All` | Delegated | List Teams the user is a member of |
| `ChannelMessage.Send` | Delegated | Post notifications to Teams channels |
| `offline_access` | Delegated | Obtain refresh tokens |

All permissions must be granted admin consent by the LU Azure AD administrator.

---

## OAuth2 Flow

IOSME uses the **Authorization Code Flow with PKCE** for delegated user permissions:

```
User → IOSME → Azure AD login page
             → User authenticates with LU credentials (SSO/MFA)
             → Azure AD redirects to https://iosme.lamar.edu/auth/microsoft/callback
             → IOSME exchanges code for access + refresh tokens
             → Tokens stored encrypted in user session
```

---

## Credential Storage

```bash
kubectl create secret generic iosme-ms365-oauth \
  --namespace iosme-prod \
  --from-literal=tenant-id='<AZURE_TENANT_ID>' \
  --from-literal=client-id='<AZURE_CLIENT_ID>' \
  --from-literal=client-secret='<AZURE_CLIENT_SECRET>'
```

---

## Features Enabled

### Calendar Sync

IOSME imports class schedules from Banner and writes them to the user's Outlook calendar:

- Creates a dedicated calendar named **"IOSME — Class Schedule"**
- Events are created/updated during enrollment sync
- Students can see their class schedule in Outlook/Teams

### Email Notifications

IOSME sends email via Microsoft Graph (`Mail.Send`) for:
- Assignment due-date reminders
- Grade release notifications
- Instructor announcements

### Teams Integration

For courses with an associated Teams team:
- IOSME posts a message to the course channel when new content is available
- Direct messages sent via IOSME appear in the user's Teams chat

---

## Configuration in Helm Values

```yaml
# values-prod.yaml
microsoft365:
  enabled: true
  secretName: iosme-ms365-oauth
  tenantAuthority: "https://login.microsoftonline.com/<AZURE_TENANT_ID>"
  graphBaseUrl: "https://graph.microsoft.com/v1.0"
  features:
    calendarSync: true
    emailNotifications: true
    teamsIntegration: true
```

---

## Token Refresh

Microsoft access tokens expire after **1 hour**. IOSME stores refresh tokens (encrypted) and automatically requests new access tokens. Refresh tokens expire after 90 days of inactivity or upon user sign-out.

---

## Troubleshooting

| Symptom | Likely Cause | Action |
|---------|-------------|--------|
| `AADSTS50034: User account does not exist` | Student not in LU Azure AD | Sync lag; student should appear within 24 h of enrollment |
| `AADSTS65001: User or admin consent required` | Consent not granted | LU Azure AD admin must grant admin consent for the app |
| `403 Insufficient privileges` | Missing Graph permission | Add permission in Azure AD app registration and re-grant consent |
| Calendar events not appearing | Token expired, calendar sync job failure | Check `iosme-m365-sync` CronJob logs |

---

## Contacts

| Role | Contact |
|------|---------|
| Azure AD Admin | LU IT Identity Team — identity@lamar.edu |
| M365 Licensing | LU IT — itservices@lamar.edu |

---

## References

- [Microsoft Graph API documentation](https://docs.microsoft.com/en-us/graph/overview)
- [Azure AD app registration](https://portal.azure.com/)
- [Secret Management](../secret-management.md)
