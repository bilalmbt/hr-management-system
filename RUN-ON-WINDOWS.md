# Run the HR Tool on Windows (or Mac) — the easy way

This app normally needs PostgreSQL, PHP 8.2, Composer, and a multi-step setup.
To avoid all of that, this folder ships a **one-command** setup using Docker.
A non-technical person only needs to install **one** program and **double-click one file**.

---

## What you need (one-time)

1. **Install Docker Desktop**
   Download it from <https://www.docker.com/products/docker-desktop> and install it.
2. **Launch Docker Desktop once.** Wait until the whale icon in the system tray
   says **“Docker Desktop is running.”**
   - On its first launch Windows may ask to enable **WSL2** and restart. Accept it.
   - Your PC needs **virtualization enabled** (it is, on almost all modern PCs).
     To check: Task Manager → Performance → CPU → *Virtualization: Enabled*.
     If it says Disabled, use the **No-Docker fallback** at the bottom of this file.

## Run the app

3. Put this project folder somewhere simple, e.g. `C:\hr-tool`.
4. **Double-click `start.bat`.**
   (On Mac/Linux, open a terminal in this folder and run `docker compose up --build`.)
5. The **first run takes a few minutes** (it downloads and builds everything).
   It is not frozen — watch the lines scroll. Wait for this line:

   ```
   HR TOOL IS READY  ->  http://localhost:8000
   ```

6. Your browser opens automatically. **Log in with:**

   | | |
   |---|---|
   | **Email** | `super@root.com` |
   | **Password** | `password` |

7. *(Optional)* The app “sends” emails (new-employee credentials, payroll, etc.).
   You can read them at **<http://localhost:8025>** (a built-in test inbox — no real
   email is sent anywhere).

## Stop / restart

- **Stop:** close the `start.bat` window, or press `Ctrl + C` in it.
- **Restart:** double-click `start.bat` again. **Your data is kept** between runs.
- **First-login tip:** go to the **Globals** page and fill in your organization’s
  settings — the app uses that data throughout.

## If something goes wrong

| Problem | Fix |
|---|---|
| “Docker was not found” | Install Docker Desktop and make sure it’s **running**, then retry. |
| Browser shows “can’t connect” for a minute | The first build is still running. Wait for the `HR TOOL IS READY` line. |
| A Windows Firewall popup appears | Click **Allow**, or the page won’t load. |
| Port 8000 already in use | Edit `docker-compose.yml`, change `"8000:8000"` to `"8001:8000"`, then open <http://localhost:8001>. |
| Want a clean slate | Run `docker compose down` then `start.bat` again. **Do not** add `-v` unless you want to erase all data. |

---

## How this works (for the curious)

`start.bat` runs `docker compose up --build`, which starts three small containers:

- **db** — PostgreSQL (the only database this app runs on without code changes).
- **app** — PHP 8.2 running the Laravel app. On first boot it auto-creates the
  app key, runs the database migrations, and loads the starter data (which is
  what creates the `super@root.com` login).
- **mailpit** — a fake mail server so the app never errors when it tries to send email.

No PHP, Node, Composer, or database needs to be installed on the PC — everything
runs inside Docker. The compiled web assets (`public/build/`) are already in the
project, so there is no `npm` build step.

---

## No-Docker fallback (only if Docker can’t run)

Use this **only** if virtualization/WSL2 can’t be enabled. It is more work and
requires editing two source files, because the app uses PostgreSQL-only SQL
(`ILIKE`) and a PostgreSQL-only `CHECK` constraint that must be adapted for SQLite.

1. Install **PHP 8.2** (with `pdo_sqlite`, `mbstring`, `openssl`, `fileinfo`,
   `curl` enabled in `php.ini`) and **Composer**. (Node is **not** needed.)
2. Edit `database/migrations/2023_05_30_075846_create_globals_table.php` and wrap
   the raw `DB::statement('ALTER TABLE globals ADD CONSTRAINT ...')` line so it is
   skipped on SQLite:
   ```php
   if (\DB::getDriverName() !== 'sqlite') {
       \DB::statement('ALTER TABLE globals ADD CONSTRAINT chk_income_tax_range CHECK (income_tax >= 0 AND income_tax <= 100)');
   }
   ```
3. Replace every `'ILIKE'` with `'like'` in the controllers under `app/Http/Controllers/`
   (Employee, Branch, Position, Department, Shift). Verify none remain:
   `grep -rc ILIKE app/` should print all zeros.
4. Create `.env` from `.env.example`, then change the DB section to SQLite — and
   **remove the `DB_DATABASE` line entirely** (an empty value breaks SQLite):
   ```
   DB_CONNECTION=sqlite
   ```
   Also set `MAIL_MAILER=log` so the app writes “emails” to `storage/logs/laravel.log`
   instead of erroring.
5. Create the database file and finish setup:
   ```
   php artisan key:generate
   type nul > database\database.sqlite
   php artisan migrate --seed --seeder=StarterSeeder
   php artisan serve
   ```
6. Open **<http://127.0.0.1:8000>** (use `127.0.0.1`, not `localhost`) and log in with
   `super@root.com` / `password`.

> Note: on SQLite, name search behaves slightly differently from the real
> PostgreSQL setup (case/Unicode handling). Fine for a demo, not for production.
