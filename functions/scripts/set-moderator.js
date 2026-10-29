const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");

const uid = process.argv[2];
if (!uid) {
    console.error("Usage: node scripts/set-moderator.js FIREBASE_AUTH_UID");
    process.exitCode = 1;
} else {
    initializeApp({ credential: applicationDefault(), projectId: "sign-up-login-82aee" });
    getAuth().getUser(uid)
        .then(async (user) => {
            await getAuth().setCustomUserClaims(uid, { ...user.customClaims, moderator: true });
            console.log(`Moderator access granted to ${uid}. The user must sign in again for the claim to refresh.`);
        })
        .catch((error) => {
            console.error(`Could not grant moderator access: ${error.message}`);
            process.exitCode = 1;
        });
}
