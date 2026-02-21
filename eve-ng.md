# EVE-NG Integration (Skyforge)

Skyforge supports multiple EVE-NG servers. Preferred mode is SSH-based integration.

## Configuration
Set EVE server JSON in `deploy/skyforge-secrets.yaml`:
- `secrets.items.skyforge-eve-servers.skyforge-eve-servers`

Example:
```json
{"servers":[{"name":"eve-ng-01","webUrl":"https://eve.local/","sshHost":"eve.local","sshUser":"root","labsPath":"/opt/unetlab/labs/admin","tmpPath":"/opt/unetlab/tmp"}]}
```

Set SSH key secret for runner access:
- `secrets.items.eve-runner-ssh-key.eve-runner-ssh-key`

Apply via Helm and restart server deployment if needed.

## API endpoints
- `GET /api/eve/servers`
- `PUT /api/eve/servers`
- `DELETE /api/eve/servers/:serverId`
- `GET /api/eve/labs` (optional `server`, `path`, `recursive`)
- `POST /api/eve/import`
- `POST /api/eve/convert`
- `GET /health/eve`
