# Banner SIS Integration — IOSME

IOSME integrates with Lamar University's **Ellucian Banner** Student Information System to retrieve enrollment data, student profiles, and course information.

---

## Integration Architecture

```
IOSME App  ──→  Banner XE API  ──→  Banner Database (Oracle)
              (REST / OAuth2)         (LU IT managed)
```

---

## Authentication: OAuth2 Client Credentials

Banner XE exposes a REST API secured with OAuth2. IOSME uses the **Client Credentials** grant type.

### Credential Storage

Credentials are stored in the `iosme-banner-oauth` Kubernetes secret (see [Secret Management](../secret-management.md)):

```yaml
client-id:     <BANNER_CLIENT_ID>
client-secret: <BANNER_CLIENT_SECRET>
token-url:     https://banner.lamar.edu/api/oauth2/token
```

### Token Refresh

IOSME automatically refreshes access tokens before expiry. The Banner API token lifetime is **30 minutes**.

If the refresh fails, IOSME raises the `BannerOAuthRefreshFailure` event and falls back to cached enrollment data (max 4-hour staleness). See [Runbook 05](../../runbooks/05-banner-oauth-refresh.md).

---

## Consumed Banner APIs

| Endpoint | Purpose | Rate Limit |
|----------|---------|------------|
| `GET /api/student/v1/students/{id}` | Student profile | 100 req/min |
| `GET /api/student/v1/academicPeriods` | Current academic periods | 20 req/min |
| `GET /api/student/v1/sectionRegistrations` | Course enrollments | 100 req/min |
| `GET /api/student/v1/instructionalEvents` | Class schedule | 100 req/min |
| `GET /api/student/v1/grades` | Grade data | 50 req/min |

---

## Data Sync

IOSME syncs Banner data on the following schedule:

| Data Type | Frequency | Method |
|-----------|-----------|--------|
| Student profiles | On login | Real-time pull |
| Enrollment/courses | Every 4 hours | Batch sync |
| Grades | Daily at 02:00 | Batch sync |
| Academic calendar | Weekly on Sunday | Batch sync |

---

## Configuration in Helm Values

```yaml
# values-prod.yaml
banner:
  baseUrl: "https://banner.lamar.edu/api"
  apiVersion: "v1"
  syncIntervalHours: 4
  oauth:
    secretName: iosme-banner-oauth
    tokenRefreshMarginSeconds: 300
```

---

## Troubleshooting

| Symptom | Likely Cause | Action |
|---------|-------------|--------|
| 401 Unauthorized on Banner API | Expired/revoked OAuth token | See Runbook 05 |
| 429 Too Many Requests | Rate limit exceeded | Reduce sync frequency or request limit increase from LU IT |
| Stale enrollment data | Batch sync job failure | Check Kubernetes CronJob logs: `kubectl logs -n iosme-prod job/iosme-banner-sync-<ID>` |
| Student not found (404) | CWID mismatch or new student | Verify CWID in Banner; may need 24 h delay for new enrollments |

---

## Contacts

| Role | Contact |
|------|---------|
| Banner Admin | LU Registrar's Office — registrar@lamar.edu |
| Banner API Support | LU IT — banner-support@lamar.edu |

---

## References

- [Runbook 05 — Banner OAuth Refresh](../../runbooks/05-banner-oauth-refresh.md)
- [Secret Management](../secret-management.md)
- [Ellucian Banner XE API Documentation](https://resources.elluciancloud.com/)
