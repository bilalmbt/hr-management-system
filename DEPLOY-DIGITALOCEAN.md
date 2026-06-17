# Deploy the HR Tool on DigitalOcean (one `docker compose up`)

> **Which DigitalOcean product?** Use a **Droplet** (a normal Linux server).
> A Droplet is the only DigitalOcean product that runs `docker compose`.
> **App Platform will not work here** — it ignores `docker-compose.yml` and can
> only deploy one container, with no bundled database. The whole point of this
> setup (app + PostgreSQL + mail in one command) needs a Droplet.

The same stack you run locally runs on the server. No code changes, no extra
services to wire up — Postgres and a mail catcher are bundled in.

---

## 1. Create the Droplet (one time, ~3 minutes)

1. In the DigitalOcean control panel: **Create → Droplets**.
2. **Choose an image →** the **Marketplace** tab → search **“Docker”** and pick the
   **Docker on Ubuntu** image. (This comes with Docker + Docker Compose already
   installed, so there is nothing else to set up.)
3. **Size:** Basic, **2 GB RAM / 1 vCPU** or larger (the first build needs ~2 GB).
4. **Authentication:** add your SSH key (recommended) or set a password.
5. Click **Create Droplet** and copy its **public IP address**.

---

## 2. Deploy (one time)

SSH into the Droplet (replace with your IP):

```bash
ssh root@YOUR_DROPLET_IP
```

Then run:

```bash
git clone https://github.com/jarvisbot19/hr-management-system.git hr-tool
cd hr-tool

# (Recommended) put the app on the normal web port and set its address:
cp deploy.env.example .env
nano .env            # set APP_PORT=80, APP_URL=http://YOUR_DROPLET_IP, a DB_PASSWORD

# Open the web port in the server firewall (the Docker image ships ufw enabled):
ufw allow 80/tcp     # or: ufw allow 8000/tcp if you keep the default port

# Build and launch everything in the background:
docker compose up -d --build
```

The first build takes a few minutes (it downloads images and installs
dependencies). When it finishes, the app auto-creates its key, runs the database
migrations, and seeds the starter data.

**Open `http://YOUR_DROPLET_IP`** (or `http://YOUR_DROPLET_IP:8000` if you kept the
default port) and log in:

| | |
|---|---|
| **Email** | `super@root.com` |
| **Password** | `password` |

> ⚠️ **Change this password immediately** after the first login — this is a
> public server.

If you skip the `.env` step entirely, `docker compose up -d --build` still works
with defaults (port **8000**); just remember to `ufw allow 8000/tcp` and open
`http://YOUR_DROPLET_IP:8000`.

---

## 3. Day-to-day operations

```bash
docker compose logs -f app      # watch the app logs (troubleshooting)
docker compose ps               # see what's running
docker compose restart app      # restart just the app
docker compose down             # stop everything (DATA IS KEPT)
docker compose up -d            # start again

# Update to the latest code:
git pull
docker compose up -d --build
```

- **Data** lives in the `hrtool_pgdata` Docker volume and **survives restarts,
  reboots, and rebuilds.** Only `docker compose down -v` (note the `-v`) erases it
  — don't use `-v` unless you want a clean slate.
- The Droplet reboots cleanly: `restart: unless-stopped` brings the app back up
  automatically.

---

## 4. Optional: a real domain + automatic HTTPS

If you have a domain, point its DNS **A record** at the Droplet IP, then use the
included Caddy add-on (free auto-renewing Let's Encrypt certificates):

```bash
# in .env:  DOMAIN=hr.example.com   and   APP_URL=https://hr.example.com
ufw allow 80/tcp && ufw allow 443/tcp
docker compose -f docker-compose.yml -f docker-compose.caddy.yml up -d --build
```

Now the app is at **https://hr.example.com** with a valid certificate. (With this
add-on the app is reached only through Caddy; port 8000 is no longer published.)

---

## 5. Notes & gotchas

| Topic | What to know |
|---|---|
| **Mail** | By default outgoing mail is caught by the internal **Mailpit** inbox so the app never errors. Its UI is bound to `127.0.0.1` (not public). To read it, tunnel from your laptop: `ssh -L 8025:127.0.0.1:8025 root@YOUR_DROPLET_IP` then open `http://localhost:8025`. For **real** email, set `MAIL_MAILER` + SMTP credentials in `docker/app.env`. |
| **Debug is off** | `APP_DEBUG=false` / `APP_ENV=production` are set in `docker-compose.yml` (safe for a public server). If a page 500s, read `docker compose logs -f app`. |
| **App server** | The app uses `php artisan serve`, which is fine for a small team / internal tool. For heavy traffic, ask to swap in nginx + php-fpm. |
| **Database password** | Set `DB_PASSWORD` in `.env` before the **first** `up`. Postgres only reads it when its data volume is first created. |
| **Sizing** | 1 GB Droplets can run out of memory during the first build. Use 2 GB+, or add swap. |
| **Backups** | Enable DigitalOcean weekly backups on the Droplet, or `docker compose exec db pg_dump -U hr employees_management > backup.sql`. |

---

For running it on a personal Windows/Mac computer instead of a server, see
[RUN-ON-WINDOWS.md](RUN-ON-WINDOWS.md).
