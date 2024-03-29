# Grabakey Backend

MVP

- cowboy + sqlite
- single key per-email
- email authentication
- curl as client
- ed25519 only
- AuthorizedKeysCommand plugin
- User: id (uuid), email, data, token

Use Cases

- Create user: 
  - email -> id=new, token=new and send to email 
  - new token created and sent every time
- Update user: id + data + token -> data=updated, token=new
- Install sshd plugin
- Purge cron
  - User with default data after N hours

API

- POST /api/user <- email -> id+token
- DELETE /api/user/:id <- token
- PUT /api/user/:id <- token+data
- GET /api/user/:id -> data

Errors

- curl -v localhost:31681/api/userX -d user@grabakey.org
  - 404 not found
  - 500 No on-conflict found (on docker only)
- curl -v localhost:31681/api/user/X -X DELETE
- curl -v localhost:31681/api/user -X POST
  - 400 bad request (failed validation)
  - 500 internal error (on exception)
- curl -v localhost:31681/api/user -X DELETE
  - 500 internal error (on :stop)

```bash
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub
iex -S mix
curl -v localhost:31681/api/user -d user@grabakey.org
sqlite3 .database/grabakey_dev.db "select * from users"
curl -v localhost:31681/api/user/01H2H215K5A56YBNKVE3E008ST
curl -v localhost:31681/api/user/01H2H215K5A56YBNKVE3E008ST -X PUT -H "Gak-Token: 01H2H215K5JXZ7HFMT8EA96RHY" -d "UPDATED"
curl -v localhost:31681/api/user/01H2H215K5A56YBNKVE3E008ST -X PUT -H "Gak-Token: 01H2H215K5JXZ7HFMT8EA96RHY" -d @$HOME/.ssh/id_ed25519.pub
curl -v localhost:31681/api/user/01H2H215K5A56YBNKVE3E008ST -X DELETE -H "Gak-Token: 01H2H1WV7SMEJR4E19HY7S0J38"

# deploy to grabakey.org
./grabakey deploy

export GAK_MAILER_ENABLED=false
export GAK_MAILER_ENABLED=true

#run dev locally
iex -S mix
sshuttle -r grabakey.org 0.0.0.0/0

# run prod release locally
./grabakey local
sshuttle -r grabakey.org 0.0.0.0/0

# bring production db to dev
./grabakey fetch-backup
```

## Todo

- Cache headers
- Purge cron job

## Howto

```bash
mix new gak_backend --module Grabakey --app grabakey --sup
cd gak_backend
mix ecto.gen.repo -r Grabakey.Repo
mix ecto.gen.migration create_users
mix ecto.migrate
sqlite3 .database/grabakey_test.db ".schema users"
sqlite3 .database/grabakey_dev.db ".schema users"
```

## Future

- CI/CD
- CDN
- 2FA
- CLI

## References

- https://github.com/woylie/ecto_ulid
- https://www.davekuhlman.org/cowboy-rest-add-get-update-list.html
- https://ninenines.eu/docs/en/cowboy/2.9/guide/rest_flowcharts/
- https://ninenines.eu/docs/en/gun/2.0/guide/
