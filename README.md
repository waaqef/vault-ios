# [vault]

A personal app for storing and working on music projects, inspired by [untitled].

Beats, demos and ideas live in projects and folders, with no file limit. Upload from your phone or computer,
play everything back with waveforms, star the keepers and mark the throwaways, and edit the actual audio
(varispeed, pitch, EQ, compressor, gain, trims and fades) without leaving the app. Projects or single tracks can be
shared with a link, so people can listen, leave comments at a moment in the track, and you can see who played what.
BPM and key are detected automatically, played songs are kept on your device so they don't download twice, and it
all syncs between iPhone and computer.

It's free to run: the app is hosted on Cloudflare, and the music is stored on Backblaze B2.

## [vault] for iPhone

This repo is the iPhone app: a small native shell that shows the live [vault] web app full-screen, and adds what
Safari won't allow a website:

- **Real haptics** (taps while swiping, dragging dials, starring…)
- **Background playback** that keeps going with the screen locked or the silent switch on
- **Downloads** (ZIPs, songs, backups) open the share sheet, so you can Save to Files or AirDrop them

It loads https://vault.choseroxy.workers.dev, so website updates show up in the app straight away; there's nothing to rebuild.

## Do I need to update the app?

**No.** You install it once. The app is a window onto the live [vault] website, so every new feature and fix
shows up in it automatically the next time you open it, the same moment it reaches the website. You never need to
download a new `.ipa` to get updates.

The only things you might do now and then:

- **Re-sign every 7 days** (free Apple ID only). That's Sideloadly keeping the app allowed to open, not an update:
  same app, same version. Turn on Sideloadly's auto-refresh and you won't have to think about it.
- **Reinstall only if this repo's native code changes** (the haptics, background audio or download handling), which
  is rare. If that happens it'll be mentioned in the commit history here.

If something new doesn't show up, fully close the app (swipe it away) and open it again.

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
