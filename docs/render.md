# Deploy the API on Render

This backend is configured for [Render](https://render.com) using Docker. The repo includes a `render.yaml` Blueprint that provisions:

- PostgreSQL (`resume-builder-db`)
- Web service (`resume-builder-api`)
- Background worker (`resume-builder-worker`) for GoodJob

## Prerequisites

1. A [Render](https://render.com) account
2. This repository pushed to GitHub or GitLab
3. An AWS S3 bucket for profile photo uploads (production uses Active Storage with S3)
4. Optional: SendGrid API key for password reset emails

## Quick deploy (Blueprint)

1. In Render, click **New > Blueprint**.
2. Connect the `resume-builder-backend` repository.
3. Set **Blueprint path** to `render.yaml`.
4. Render will prompt for secret/synced environment variables. Set at minimum:

| Variable | Example | Required |
| --- | --- | --- |
| `SERVER_HOST` | `resume-builder-api.onrender.com` | Yes |
| `PASSWORD_RESET_URL` | `https://your-frontend.com/en/reset-password` | Yes |
| `AWS_ACCESS_KEY_ID` | AWS IAM access key | Yes (for uploads) |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret | Yes (for uploads) |
| `S3_BUCKET_NAME` | `your-bucket-name` | Yes (for uploads) |
| `AWS_BUCKET_REGION` | `us-east-1` | Yes (for profile photo uploads) |
| `SENDGRID_API_KEY` | SendGrid API key | Optional |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID | Optional (social login) |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret | Optional (social login) |
| `FACEBOOK_APP_ID` | Meta app ID | Optional (social login) |
| `FACEBOOK_APP_SECRET` | Meta app secret | Optional (social login) |

> **Note:** If S3 variables are missing, the API will still start using local disk storage. Profile photos will not persist across deploys until S3 is configured.

5. Click **Apply**. Render builds the Docker image, creates the database, and starts the web and worker services.

After the first deploy, open the web service and confirm the health check passes:

```text
GET https://<your-service>.onrender.com/api/v1/status
```

Expected response:

```json
{ "online": true }
```

## Manual deploy (Dashboard)

If you prefer not to use the Blueprint:

### 1. Create PostgreSQL

- **New > PostgreSQL**
- Copy the **Internal Database URL**

### 2. Create web service

- **New > Web Service**
- Connect this repo
- **Language:** Docker
- **Dockerfile path:** `./Dockerfile`
- **Instance type:** Free or Starter

Environment variables:

```bash
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true
DATABASE_URL=<internal postgres url>
SECRET_KEY_BASE=<run: openssl rand -hex 64>
SERVER_HOST=<your-service>.onrender.com
PASSWORD_RESET_URL=https://your-frontend.com/en/reset-password
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
S3_BUCKET_NAME=...
AWS_BUCKET_REGION=...
WEB_CONCURRENCY=1
RAILS_MAX_THREADS=3
```

Leave **Docker Command** empty to use the Dockerfile default (`bundle exec puma`).

Set **Health Check Path** to `/api/v1/status`.

### 3. Create background worker

- **New > Background Worker**
- Same repo and Dockerfile
- **Docker Command:** `bundle exec good_job start`
- Reuse the same environment variables as the web service (including the same `SECRET_KEY_BASE` and `DATABASE_URL`)

### 4. Migrations

On the **free** plan, Render does not run a pre-deploy command. Migrations run automatically when the web container starts because `bin/docker-entrypoint` calls `rails db:prepare` before Puma boots.

On a **paid** plan, you can uncomment `preDeployCommand` in `render.yaml`:

```yaml
preDeployCommand: bundle exec rails db:prepare && ./bin/release.sh
```

## Post-deploy

### Create an admin user

Seeds run only in development. In production, open a Render shell on the web service:

```bash
bundle exec rails console
```

```ruby
AdminUser.create!(email: 'admin@example.com', password: 'change-me-now')
```

### Run seeds locally against production (optional)

Not recommended for production unless you intentionally want demo data.

### Update CORS / frontend URL

CORS currently allows all origins in `config/initializers/rack_cors.rb`. Tighten this to your frontend domain before going live.

Set `PASSWORD_RESET_URL` to your deployed frontend reset-password page.

Set `SERVER_HOST` to your Render hostname (no `https://` prefix). This is used for Active Storage URLs and mailer links.

## Monorepo note

If this backend lives in a subdirectory of a larger repository, set **Root Directory** to `resume-builder-backend` in Render (or add `rootDir: resume-builder-backend` to each service in `render.yaml`).

## Troubleshooting

| Issue | Fix |
| --- | --- |
| Health check fails | Confirm `/api/v1/status` returns 200 and `DATABASE_URL` is the **internal** Postgres URL |
| `No region was provided` / worker crash on boot | Set `AWS_BUCKET_REGION` (e.g. `us-east-1`) plus the other three S3 env vars on the web **and** worker services |
| Profile photo upload fails | Verify all four AWS/S3 env vars and bucket CORS policy |
| Password reset email missing | Set `SENDGRID_API_KEY`; otherwise mailers are configured but not sent |
| Background jobs stuck | Ensure `resume-builder-worker` is running and shares `DATABASE_URL` + `SECRET_KEY_BASE` with the web service |
| App sleeps on free tier | Free web services spin down after inactivity; first request may take ~30s |

## Useful commands

Open a shell on the web service from the Render Dashboard, then:

```bash
bundle exec rails db:migrate
bundle exec rails console
bundle exec rails feature_flags:initialize
```
