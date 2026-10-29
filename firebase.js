

import { initializeApp } from "https://www.gstatic.com/firebasejs/13.0.0/firebase-app.js";
import { getAuth, connectAuthEmulator } from "https://www.gstatic.com/firebasejs/13.0.0/firebase-auth.js";
import { getFirestore, connectFirestoreEmulator } from "https://www.gstatic.com/firebasejs/13.0.0/firebase-firestore.js";
import { getFunctions, connectFunctionsEmulator } from "https://www.gstatic.com/firebasejs/13.0.0/firebase-functions.js";

const firebaseConfig = {
    apiKey: "AIzaSyDy7WeNe3xmQTMlt6obzeJoTowpyWn8OMk",
    authDomain: "sign-up-login-82aee.firebaseapp.com",
    projectId: "sign-up-login-82aee",
    storageBucket: "sign-up-login-82aee.firebasestorage.app",
    messagingSenderId: "218140270644",
    appId: "1:218140270644:web:d1a89329c8a16e9dc36a61"
};

const app = initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);
export const functions = getFunctions(app, "us-central1");

if (["localhost", "127.0.0.1", "::1"].includes(window.location.hostname)) {
    connectAuthEmulator(auth, "http://127.0.0.1:9099");
    connectFirestoreEmulator(db, "127.0.0.1", 8080);
    connectFunctionsEmulator(functions, "127.0.0.1", 5001);
}