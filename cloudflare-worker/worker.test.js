import test from "node:test";
import assert from "node:assert/strict";
import worker from "./worker.js";

test("health endpoint is available without Firebase credentials", async () => {
    const response = await worker.fetch(new Request("https://www.starboundarcade.com/api/health"), {});
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { status: "ok", backend: "cloudflare-worker" });
});

test("preflight allows configured site origins and authorization headers", async () => {
    const response = await worker.fetch(new Request("https://www.starboundarcade.com/api/updatePlayerProfile", {
        method: "OPTIONS",
        headers: { Origin: "https://www.starboundarcade.com" }
    }), {});
    assert.equal(response.status, 204);
    assert.equal(response.headers.get("Access-Control-Allow-Origin"), "https://www.starboundarcade.com");
    assert.match(response.headers.get("Access-Control-Allow-Headers"), /Authorization/i);
});

test("requests from an unconfigured origin are rejected", async () => {
    const response = await worker.fetch(new Request("https://www.starboundarcade.com/api/updatePlayerProfile", {
        method: "POST",
        headers: {
            Origin: "https://untrusted.example",
            "Content-Type": "application/json"
        },
        body: JSON.stringify({ data: {} })
    }), {});
    assert.equal(response.status, 403);
});

test("online API requires a Firebase bearer token", async () => {
    const response = await worker.fetch(new Request("https://www.starboundarcade.com/api/updatePlayerProfile", {
        method: "POST",
        headers: {
            Origin: "https://www.starboundarcade.com",
            "Content-Type": "application/json"
        },
        body: JSON.stringify({ data: {} })
    }), {});
    assert.equal(response.status, 401);
    assert.equal((await response.json()).error.message, "Sign in to use the arcade.");
});

test("account deletion requires an authenticated Firebase bearer token", async () => {
    const response = await worker.fetch(new Request("https://www.starboundarcade.com/api/deleteAccount", {
        method: "POST",
        headers: {
            Origin: "https://www.starboundarcade.com",
            "Content-Type": "application/json"
        },
        body: JSON.stringify({ data: {} })
    }), { PROJECT_ID: "sign-up-login-82aee" });
    assert.equal(response.status, 401);
    assert.equal((await response.json()).error.message, "Sign in to use the arcade.");
});
