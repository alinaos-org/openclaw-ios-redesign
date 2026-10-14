# TestFlight builds

The fork-only [Simple UI TestFlight](/.github/workflows/simple-ui-testflight.yml)
workflow builds the app on a GitHub-hosted Mac, signs it for the App Store, and
uploads it to TestFlight. It runs only when you start it, so pushes to
`simple-ui` never upload anything.

The fork uses its own identifiers, so it installs alongside upstream's
OpenClaw app:

| Product | Identifier |
| --- | --- |
| App | `ai.controlstack.openclaw` |
| Share extension | `ai.controlstack.openclaw.share` |
| Live Activity widget | `ai.controlstack.openclaw.activitywidget` |
| Watch app | `ai.controlstack.openclaw.watchkitapp` |
| App group | `group.ai.controlstack.openclaw.shared` |

To change the prefix, edit the `env` block at the top of the workflow and
register the matching identifiers below.

## One-time setup

You need an [Apple Developer Program](https://developer.apple.com/programs/)
membership. You don't need a Mac.

1. **Find your Team ID.** It's the 10-character code under Membership details
   at [developer.apple.com/account](https://developer.apple.com/account).
2. **Register the app group.** Under Certificates, Identifiers & Profiles →
   Identifiers, add an App Group with the identifier
   `group.ai.controlstack.openclaw.shared`.
3. **Register four App IDs** under Identifiers → App IDs → App:
   - `ai.controlstack.openclaw`: turn on **Push Notifications**, **HealthKit**,
     and **App Groups**, then configure App Groups to use the group from step 2.
   - `ai.controlstack.openclaw.share`: turn on **App Groups** with the same
     group.
   - `ai.controlstack.openclaw.activitywidget` and
     `ai.controlstack.openclaw.watchkitapp`: no capabilities.
4. **Create the app record.** In [App Store Connect](https://appstoreconnect.apple.com)
   → Apps → **+** → New App, pick iOS and the bundle ID `ai.controlstack.openclaw`.
   The name must be unique on the App Store, so pick one of your own. The
   SKU can be anything.
5. **Create an API key.** In App Store Connect → Users and Access →
   Integrations → App Store Connect API → Team Keys, generate a key with
   **Admin** access. Admin access lets the workflow create the distribution
   certificate and profiles. Download the `.p8` file (Apple only lets you
   download it once), and note the Key ID and the Issuer ID.
6. **Create a private signing repo.** The workflow keeps the certificate and
   profiles there, encrypted with a password you choose:

   ```bash
   gh repo create mmango7474/ios-signing --private --add-readme
   ```

   Then create a [fine-grained personal access token](https://github.com/settings/personal-access-tokens/new)
   limited to that repo, with **Contents: Read and write**.
7. **Add the GitHub settings.** Run these commands in this repo. Each
   `gh secret set` command asks you to paste its value, so nothing lands in
   your shell history:

   ```bash
   gh variable set APPLE_TEAM_ID -R mmango7474/openclaw-ios-redesign --body YOURTEAMID
   gh variable set IOS_SIGNING_REPO -R mmango7474/openclaw-ios-redesign --body mmango7474/ios-signing
   gh secret set APP_STORE_CONNECT_KEY_ID -R mmango7474/openclaw-ios-redesign
   gh secret set APP_STORE_CONNECT_ISSUER_ID -R mmango7474/openclaw-ios-redesign
   gh secret set APP_STORE_CONNECT_KEY_CONTENT -R mmango7474/openclaw-ios-redesign < AuthKey_XXXXXXXXXX.p8
   gh secret set MATCH_PASSWORD -R mmango7474/openclaw-ios-redesign
   gh secret set MATCH_GIT_TOKEN -R mmango7474/openclaw-ios-redesign
   ```

   `MATCH_PASSWORD` encrypts the signing repo, so pick a long random password
   and keep a copy. `MATCH_GIT_TOKEN` is the token from step 6.

## Upload a build

Start the workflow from the Actions tab, or run:

```bash
gh workflow run simple-ui-testflight.yml -R mmango7474/openclaw-ios-redesign --ref simple-ui
```

The first run creates the Apple Distribution certificate and the four App
Store profiles, then saves them to the signing repo. Later runs reuse them.

Apple processes each upload for 10 to 30 minutes. To install the build:

1. In App Store Connect → your app → TestFlight, add an internal testing group
   and add yourself. Members of your App Store Connect team can test without
   Beta App Review.
2. Install [TestFlight](https://apps.apple.com/app/testflight/id899247664) on
   your iPhone and sign in with the same Apple Account.
3. Open the invite and install. New builds show up there automatically.

Each upload uses the workflow run number as its build number. The version
follows the repo's `package.json`, the same as upstream.

## Differences from upstream's App Store build

- **Push notifications** use direct APNs delivery (the Release
  `localProduction` push mode). Upstream's hosted push relay only serves the
  official app, so pushes reach this build only if your gateway sends APNs
  pushes for `ai.controlstack.openclaw` itself.
- **App Attest** is off. Only the hosted push relay uses it.

## Troubleshooting

- **"TestFlight setup is incomplete"**: the run names each missing variable or
  secret. Add those from step 7.
- **"Could not find App ID"** or **"No profile matching"**: an identifier from
  step 3 is missing or misspelled.
- **A profile is missing an entitlement** after you change an App ID's
  capabilities: rerun the workflow with **Recreate the App Store profiles**
  checked.
- **The upload says the build already exists**: start a new run instead of
  re-running the old one. Each new run gets a higher build number.
