# Courier

A self-hosted Phoenix LiveView application that manages [Calibre](https://calibre-ebook.com/) news recipes and delivers epubs to e-readers via email on a schedule.

**Features:**
- Manage `.recipe` files with a built-in Python code editor
- Register e-reader devices by email address
- Subscribe devices to recipes
- Schedule deliveries by time of day and day of week
- Delivery log with per-run status and output

Ships as a single Docker image with Calibre bundled.

---

## TrueNAS SCALE Setup (Electric Eel 24.10+)

### 1. Create a dataset for persistent storage

In the TrueNAS web UI go to **Datasets → Add Dataset** and create a dataset for Courier's SQLite database. Note the full path — e.g. `/mnt/tank/courier`.

### 2. Add the app via custom YAML

In TrueNAS go to **Apps → Discover Apps → Custom App**, switch to the **YAML** tab, and paste the following — filling in your values:

```yaml
services:
  courier:
    image: ghcr.io/qmalcolm/courier:latest
    restart: unless-stopped
    ports:
      - "4000:4000"
    volumes:
      - /mnt/tank/courier:/data
    environment:
      # Database (persisted to your dataset)
      DATABASE_PATH: /data/courier.db

      # Optional: set for sessions that survive restarts (generate with: mix phx.gen.secret)
      # SECRET_KEY_BASE: ""

      # Set to your TrueNAS hostname or IP
      PHX_HOST: truenas.local

      # SMTP delivery settings
      COURIER_SMTP_FROM: you@gmail.com
      COURIER_SMTP_USERNAME: you@gmail.com
      # Use a Gmail App Password, not your account password
      # https://myaccount.google.com/apppasswords
      COURIER_SMTP_PASSWORD: your_app_password
      COURIER_SMTP_RELAY: smtp.gmail.com
      COURIER_SMTP_PORT: "587"
      COURIER_SMTP_ENCRYPTION: TLS

      # Optional: path to a Calibre library for archiving delivered epubs
      # Create a second volume entry pointing to your library and uncomment:
      # COURIER_CALIBRE_LIBRARY: /library
```

Click **Save**. The container will pull and start. Courier will be available at `http://<truenas-ip>:4000`.

### 4. Upgrading

When a new image is published, go to **Apps → courier → Update** to pull the latest version. Your database is safe on the dataset volume.

---

## Calibre / CalibreWeb library integration

Courier can archive every delivered epub into a Calibre library, making it available in Calibre or CalibreWeb automatically. After each successful conversion, it runs `calibredb add` to insert the epub into the library.

To enable it, mount your Calibre library directory into the Courier container and set `COURIER_CALIBRE_LIBRARY`.

**TrueNAS SCALE YAML — add a second volume and uncomment the env var:**

```yaml
services:
  courier:
    image: ghcr.io/qmalcolm/courier:latest
    volumes:
      - /mnt/tank/courier:/data
      - /mnt/tank/calibre/library:/library   # same dataset CalibreWeb uses
    environment:
      DATABASE_PATH: /data/courier.db
      COURIER_CALIBRE_LIBRARY: /library      # enables calibredb add after each delivery
      # ... rest of your config
```

The path `/mnt/tank/calibre/library` should match whatever dataset your CalibreWeb container mounts as its library — check your CalibreWeb app configuration to find it.

**How it works:** Courier shells out to its bundled `/opt/calibre/calibredb`, which writes the epub and metadata directly into `metadata.db` on the shared library directory. CalibreWeb reads from that same file, so new articles appear on the next page load with no manual scan required.

---

## Environment variable reference

| Variable | Required | Default | Description |
|---|---|---|---|
| `DATABASE_PATH` | Yes | — | Absolute path to the SQLite database file |
| `SECRET_KEY_BASE` | No | — | Phoenix secret key — if set, sessions survive restarts; if unset, a random key is generated on each startup (generate with `mix phx.gen.secret`) |
| `PHX_HOST` | No | `localhost` | Hostname used in generated URLs |
| `PORT` | No | `4000` | Port the HTTP server listens on |
| `PHX_SCHEME` | No | `http` | Set to `https` if behind a TLS-terminating reverse proxy |
| `COURIER_CALIBRE_PATH` | No | `/opt/calibre` | Path to Calibre binaries inside the container |
| `COURIER_CALIBRE_LIBRARY` | No | — | Path to a Calibre library for archiving epubs (optional) |
| `COURIER_SMTP_FROM` | No | — | Sender address shown in the `From:` header of delivered emails |
| `COURIER_SMTP_USERNAME` | No | — | SMTP authentication username — for Gmail, this is the same as `COURIER_SMTP_FROM` |
| `COURIER_SMTP_PASSWORD` | No | — | SMTP password |
| `COURIER_SMTP_RELAY` | No | `smtp.gmail.com` | SMTP relay host |
| `COURIER_SMTP_PORT` | No | `587` | SMTP port |
| `COURIER_SMTP_ENCRYPTION` | No | `TLS` | `TLS` or `STARTTLS` |

---

## Local development

```bash
mix setup
mix phx.server
```

Visit [localhost:4000](http://localhost:4000).

Requires Elixir 1.18+, Erlang/OTP 28+, and Node.js (for CodeMirror assets). Calibre is only needed at runtime for actual recipe delivery — the UI works without it locally.
