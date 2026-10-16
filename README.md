# [vault] for iPhone

A small native app that shows the live [vault] web app full-screen, and adds what Safari won't allow a website:

- **Real haptics** (taps while swiping, dragging dials, starring…)
- **Background playback** that keeps going with the screen locked or the silent switch on
- **Downloads** (ZIPs, songs, backups) open the share sheet, so you can Save to Files or AirDrop them

It loads https://vault.choseroxy.workers.dev, so website updates show up in the app straight away; there's nothing to rebuild.

## Getting the app

1. Open the **Releases** section of this repo (or the **Actions** tab → latest run → *vault-ipa*) and download `vault.ipa`.
2. Open **Sideloadly** on your PC, plug in your iPhone, drag `vault.ipa` in, enter your Apple ID, and press **Start**.
3. On the iPhone: **Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.
4. If iOS asks, turn on **Developer Mode** (Settings → Privacy & Security → Developer Mode) and restart.

With a free Apple ID the app has to be re-signed every 7 days. Sideloadly can do that automatically if your PC and
iPhone are on the same Wi-Fi (turn on its auto-refresh option).

## Building

Every push builds a fresh `vault.ipa` on a GitHub-hosted Mac (see `.github/workflows/build.yml`).
You can also run it by hand: **Actions → Build iPhone app → Run workflow**.
