# Starbound Arcade platform setup

The arcade uses Firebase Authentication and Firestore in project `sign-up-login-82aee`. The production API runs on a Cloudflare Worker so Firebase Cloud Functions billing is not required. Cloudflare Workers and Firestore still have their own free-plan quotas and limits.

## Production setup without Firebase billing

1. Make sure Firebase Authentication and Cloud Firestore are enabled in the Firebase project. Keep the project on the Firebase Spark plan; do not deploy Cloud Functions.
2. Install Node.js 22, Firebase CLI, and Wrangler, then sign in to both platforms:
   ```powershell
   npm install --global firebase-tools
   npm install --global wrangler
   firebase login
   cd cloudflare-worker
   wrangler login
   ```
3. Create a Google Cloud service account for the Firebase project and grant it the **Cloud Datastore User** (`roles/datastore.user`) role. Create a JSON key for it. This credential lets the Worker access Firestore while browser writes remain blocked by Firestore rules.
4. Store the entire service-account JSON key as a Cloudflare Worker secret. Run this from `cloudflare-worker`; paste the key only into Wrangler's prompt:
   ```powershell
   wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON
   ```
   Never paste the JSON key into chat, commit it to the repository, or put it in a website file. If it is exposed, revoke that key immediately in Google Cloud Console.
5. Deploy the Worker:
   ```powershell
   wrangler deploy
   ```
   `wrangler.toml` routes `/api/*` for both `starboundarcade.com` and `www.starboundarcade.com` to this Worker. The domain's DNS records must be proxied through Cloudflare. Check that `https://www.starboundarcade.com/api/health` returns `{"status":"ok","backend":"cloudflare-worker"}`.
6. Deploy only Firestore rules and indexes from the project root; this does not deploy Cloud Functions:
   ```powershell
   cd ..
   firebase deploy --project sign-up-login-82aee --only firestore:rules,firestore:indexes
   ```
7. To grant a trusted account moderator access, use an administrator machine already authenticated with Google Application Default Credentials:
   ```powershell
   cd functions
   npm install
   gcloud auth application-default login
   node scripts/set-moderator.js FIREBASE_AUTH_UID
   ```
   The user must sign out and sign in again before the moderator tab is authorized. Never expose service-account credentials in the website.
8. Serve the project over HTTP (not `file://`), sign in, and open `community.html`.

## Local emulator development

When the site is opened from `localhost` or `127.0.0.1`, Firebase Auth, Firestore, and Functions connect to the local emulators configured in `firebase.json`. Local requests continue to use the Functions emulator; production requests use the Cloudflare Worker.

1. From the project folder, start the emulators:
   ```powershell
   firebase emulators:start --project sign-up-login-82aee
   ```
2. In a second terminal, serve the site:
   ```powershell
   npx http-server . -p 6464
   ```
3. Open `http://localhost:6464`. Keep both terminals running. Emulator data is separate from the deployed cloud project.

## Freeplay options

- Browser freeplay offers Easy, Normal, and Hard difficulty. Published community games keep the difficulty set by their creator.
- Every browser freeplay game has a Default 30-second timer, a custom duration from 1 to 999999999999999 seconds, and Endless mode. Planet Hopper follows the selected time mode too. The time-mode and custom-duration choices are remembered in that browser.
- Signed-in players receive a persistent random 32-character public ID in the `player` query parameter of internal page links. This identifies a player for link sharing; it is not a login credential and does not grant account access.
- The signed-in hub includes an all-time creator leaderboard and an all-time leaderboard for server-validated ranked points. Ranked points currently come from online Star Catcher; totals start accumulating when the new Worker/Functions are deployed. Daily ranked boards remain separate.
- Account settings are in the hub's Settings tab. Account deletion requires typing `DELETE`, confirming the account password, and reauthenticating. It permanently removes the Firebase account, profile, created levels, comments, reports, matchmaking entries, match records, and ranked score records.
- To publish these backend and leaderboard changes, deploy the website, Cloudflare Worker (`cloudflare-worker`), and Firestore indexes from the project root (`firebase deploy --only firestore:indexes`). Deploy the Firebase Functions too when using the local emulator/Functions backend.
- Deploy the updated Cloudflare Worker backend before the site files; player-profile responses must include `publicId`.
- Use `Fullscreen website` to expand any arcade page or `Fullscreen game` inside the 3D game stage to expand any game. Press `Escape` or use the same button to exit.
- Press `P` or `Escape`, or use the Pause button, to pause and resume. Sound can be toggled in the game controls.
- Power-ups grant a temporary star-score boost in Star Catcher or a one-hit shield in the survival and jumping games. Meteor Dash includes fast, standard, and heavy meteors.
- Browser personal bests are stored in that browser's local storage. They are separate from server-validated online leaderboard scores.
- The native game in `DLL` has its own build instructions and game-logic tests in `DLL/dll_compiler_code.md`.

## Platform safeguards and scope

- Firestore writes are disabled in client security rules. The Cloudflare Worker verifies Firebase ID tokens and checks active account status before creating modes, comments, reports, matchmaking entries, and scores.
- Match positions and star points are calculated in server transactions with board bounds and a move-rate limit. Casual and ranked use the same live match protocol; only ranked matches write leaderboard scores.
- Custom modes are data-only configurations based on the supported Three.js templates. The site does not accept or execute user-uploaded JavaScript.
- Comments are attributed to signed-in Firebase users. Links are held for review, reports go to the moderator queue, and moderators can approve/remove comments, remove/restore games, and suspend/restore accounts.
- Daily/weekly spotlights are generated from UTC time. Event names rotate on a simple calendar; a staffed event schedule and prizes are not configured.
- Live matchmaking and ranked scores are currently enabled for Star Catcher. The other Three.js games are playable in freeplay; their online rules are not implemented yet.
- Bot practice is local freeplay and never affects leaderboards. Moderation claims must be granted by the project owner.
- Anti-cheat here validates live-match actions and score updates on the server; it cannot prevent all client tampering or replace human moderation.


Moderator script
```powershell
.\grant-moderator.ps1 -FirebaseAuthUid YOUR_FIREBASE_UID
```