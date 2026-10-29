import { httpsCallable } from "https://www.gstatic.com/firebasejs/13.0.0/firebase-functions.js";
import { auth, functions } from "./firebase.js";

let observer;
let activePublicId;

function addPlayerIdToLinks(publicId) {
    document.querySelectorAll("a[href]").forEach((link) => {
        const url = new URL(link.href, window.location.href);
        if (url.origin !== window.location.origin
            || (url.pathname !== "/" && !url.pathname.endsWith(".html"))) return;
        if (url.searchParams.get("player") === publicId) return;
        url.searchParams.set("player", publicId);
        link.href = url.href;
    });
}

async function updateProfile(user, displayName) {
    const data = { displayName };
    if (["localhost", "127.0.0.1", "::1"].includes(window.location.hostname)) {
        return (await httpsCallable(functions, "updatePlayerProfile")(data)).data;
    }
    const response = await fetch("/api/updatePlayerProfile", {
        method: "POST",
        headers: {
            Authorization: `Bearer ${await user.getIdToken()}`,
            "Content-Type": "application/json"
        },
        body: JSON.stringify({ data })
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result?.error?.message || `Could not update player profile (${response.status}).`);
    return result.data;
}

export async function syncPlayerLink(user, displayName = user.displayName || "Player") {
    const result = await updateProfile(user, displayName);
    if (typeof result?.publicId !== "string") {
        throw new Error("The deployed arcade backend is outdated and did not return a player ID. Deploy the latest Cloudflare Worker, then reload the page.");
    }
    if (!/^[a-f0-9]{32}$/.test(result.publicId)) {
        throw new Error("The arcade backend returned a malformed player ID. Contact the site administrator.");
    }

    const currentUrl = new URL(window.location.href);
    currentUrl.searchParams.set("player", result.publicId);
    window.history.replaceState(window.history.state, "", currentUrl);
    activePublicId = result.publicId;
    addPlayerIdToLinks(result.publicId);

    if (!observer) {
        observer = new MutationObserver((records) => {
            for (const record of records) {
                record.addedNodes.forEach((node) => {
                    if (!(node instanceof Element)) return;
                    if (node.matches("a[href]") || node.querySelector("a[href]")) {
                        addPlayerIdToLinks(activePublicId);
                    }
                });
            }
        });
        observer.observe(document.body, { childList: true, subtree: true });
    }
    return result.publicId;
}
