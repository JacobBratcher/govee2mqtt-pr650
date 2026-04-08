# govee2mqtt — PR #650 build

Tiny repo that builds [`manuveli/govee2mqtt`](https://github.com/manuveli/govee2mqtt)
(the source of [wez/govee2mqtt#650](https://github.com/wez/govee2mqtt/pull/650))
into a Docker image and publishes it to GHCR.

PR #650 bumps `APP_VERSION` to `7.4.10` so the Govee API stops rejecting requests
with *"The app version is too low, please upgrade the version!"*

The image is a **drop-in replacement** for `ghcr.io/wez/govee2mqtt` — same
binary path, same `CMD`, same `/data` volume, same user.

## Image

```
ghcr.io/<your-username>/govee2mqtt-pr650:latest
ghcr.io/<your-username>/govee2mqtt-pr650:pr650
```

After the first GH Actions run finishes, go to your GitHub profile →
Packages → `govee2mqtt-pr650` → Package settings, and set visibility to
**public** (otherwise HA will fail to pull it).

## Using it on Home Assistant

### If you run govee2mqtt as the official add-on (Supervised / HAOS)

The official add-on hard-codes the upstream image, so you can't simply swap
images in the UI. Two options:

1. **Easy:** Disable the add-on, run govee2mqtt as a standalone container
   (Portainer or `docker compose`) using this image. See compose snippet below.
2. **Cleaner:** Fork [hassio-addons/addon-govee2mqtt](https://github.com/wez/govee2mqtt/tree/main/addon)
   (or wherever your add-on lives), edit `config.yaml` to point `image:` at
   `ghcr.io/<you>/govee2mqtt-pr650`, and add it as a custom add-on repo in HA.

### docker-compose snippet

```yaml
services:
  govee2mqtt:
    image: ghcr.io/<your-username>/govee2mqtt-pr650:latest
    container_name: govee2mqtt
    restart: unless-stopped
    network_mode: host  # required for LAN device discovery
    volumes:
      - ./govee-data:/data
    environment:
      GOVEE_EMAIL: your@email
      GOVEE_PASSWORD: yourpassword
      GOVEE_MQTT_HOST: <ha-ip-or-mosquitto-host>
      GOVEE_MQTT_PORT: "1883"
      GOVEE_MQTT_USER: mqttuser
      GOVEE_MQTT_PASSWORD: mqttpass
      RUST_LOG: govee=info
```

Then in HA, the existing MQTT discovery topics will reappear automatically.

## How to publish

1. Create a new GitHub repo named `govee2mqtt-pr650` (public).
2. From this folder:
   ```bash
   git init
   git add .
   git commit -m "Initial commit: build PR #650"
   git branch -M main
   git remote add origin https://github.com/<your-username>/govee2mqtt-pr650.git
   git push -u origin main
   ```
3. Watch the **Actions** tab. First build takes ~25-30 min (cross-arch Rust).
   Subsequent builds are cached and much faster.
4. Make the resulting package public (see above).
5. Pull the image on your HA host and restart govee2mqtt.

## When the upstream PR gets merged

Just stop using this image and switch back to `ghcr.io/wez/govee2mqtt:latest`.
You can delete this repo at that point.

## Trimming arm64

If your HA is x86/amd64 only, edit `.github/workflows/build.yml` and remove
`linux/arm64` from the `platforms:` list. Build time drops from ~30 min to ~8 min.
