# OneBusAway MapLibre nightly builds

Unofficial nightly APKs of the **`maplibre`** flavor of
[OneBusAway for Android](https://github.com/OneBusAway/onebusaway-android) — the build that renders
maps with [MapLibre GL Native](https://maplibre.org/) and OpenFreeMap tiles instead of Google Maps.

**This is not affiliated with or endorsed by the OneBusAway project.** Upstream ships only the
`google` flavor to Google Play, so today the only way to get a MapLibre build is to compile it
yourself. This repo exists to fill that gap and should be shut down the moment an official
distribution channel appears.

## Install

Grab the APK from the [latest release](../../releases) and sideload it. Every release is marked a
prerelease, because that is what it is.

Read this first:

- **It is signed with this repo's key**, not the OneBusAway project's.
- **Its application ID is suffixed** (`…seattlebusbot.maplibre.nightly`), so it installs *alongside*
  the Play Store app and appears in your launcher as **OneBusAway (Libre)**. It does not upgrade
  the official app, and it inherits none of its data or settings.
- **There is no migration path back.** Moving to the official app later means starting fresh.
- **It is built from unreviewed upstream `main`.** Some nights will be broken.
- Trip-planning geocoding needs a Pelias API key that these builds may not carry; the rest of the
  app is unaffected.

## How it works

`.github/workflows/nightly.yml` runs at 8pm Pacific:

1. Resolves upstream `main`, and exits early if that commit was already released.
2. Checks upstream out fresh (nothing is forked or vendored here).
3. Runs `scripts/patch-nightly.sh` to apply the app ID suffix and the rename.
4. Builds `:onebusaway-android:assembleObaMaplibreRelease` on `ubuntu-latest` with JDK 21, mirroring
   upstream's own CI.
5. Verifies the APK is actually signed, then publishes it as a dated prerelease and prunes all but
   the newest 14.

The patch script fails loudly if upstream moves the things it edits, so a restructure upstream breaks
the build rather than silently shipping an APK that impersonates the official app.

## Setup

Required repo secrets:

| Secret | |
|---|---|
| `NIGHTLY_KEYSTORE_BASE64` | `base64 -w0 nightly.jks` |
| `NIGHTLY_KEYSTORE_PASSWORD` | |
| `NIGHTLY_KEY_ALIAS` | |
| `NIGHTLY_KEY_PASSWORD` | |
| `PELIAS_API_KEY` | optional; enables trip-planning geocoding |

Generate the keystore once and **back it up** — if it is lost, every user has to uninstall and
reinstall to keep receiving nightlies:

```sh
keytool -genkeypair -v -keystore nightly.jks -alias nightly \
  -keyalg RSA -keysize 4096 -validity 10000
```

Note that GitHub disables scheduled workflows after 60 days of repository inactivity.

## Licensing

The app source is OneBusAway's, under its own license; see
[upstream](https://github.com/OneBusAway/onebusaway-android). Only the workflow and scripts in this
repo are mine.
