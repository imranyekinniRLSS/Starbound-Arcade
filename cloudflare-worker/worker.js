const MATCH_SECONDS = 30;
const MOVE_INTERVAL_MS = 75;
const GAME_TYPES = new Set(["catch", "dodge", "hop", "dash"]);
const MATCH_MODES = new Set(["casual", "ranked"]);
const FIREBASE_JWKS_URL = "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";
const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
const GOOGLE_SCOPE = "https://www.googleapis.com/auth/datastore";
const tokenCache = new Map();

class ApiError extends Error {
    constructor(status, message) {
        super(message);
        this.status = status;
    }
}

function base64UrlEncode(value) {
    const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
    let binary = "";
    for (const byte of bytes) binary += String.fromCharCode(byte);
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function decodeBase64Url(value) {
    const base64 = value.replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
    return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
}

function decodeJwtPart(value) {
    return JSON.parse(new TextDecoder().decode(decodeBase64Url(value)));
}

function pemToBytes(pem) {
    const encoded = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
    return decodeBase64Url(encoded.replace(/\+/g, "-").replace(/\//g, "_"));
}

function firestoreValue(value) {
    if (value === null) return { nullValue: null };
    if (typeof value === "object" && value !== null && typeof value.$timestamp === "string") {
        return { timestampValue: value.$timestamp };
    }
    if (typeof value === "string") return { stringValue: value };
    if (typeof value === "boolean") return { booleanValue: value };
    if (typeof value === "number") {
        return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
    }
    if (Array.isArray(value)) return { arrayValue: { values: value.map(firestoreValue) } };
    if (typeof value === "object" && value !== null) {
        return { mapValue: { fields: firestoreFields(value) } };
    }
    throw new ApiError(400, "Unsupported Firestore value.");
}

function firestoreFields(value) {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, firestoreValue(item)]));
}

function fromFirestoreValue(value) {
    if ("stringValue" in value) return value.stringValue;
    if ("integerValue" in value) return Number(value.integerValue);
    if ("doubleValue" in value) return value.doubleValue;
    if ("booleanValue" in value) return value.booleanValue;
    if ("nullValue" in value) return null;
    if ("timestampValue" in value) return value.timestampValue;
    if ("arrayValue" in value) return (value.arrayValue.values || []).map(fromFirestoreValue);
    if ("mapValue" in value) return fromFirestoreFields(value.mapValue.fields || {});
    if ("referenceValue" in value) return value.referenceValue;
    return null;
}

function fromFirestoreFields(fields = {}) {
    return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, fromFirestoreValue(value)]));
}

function decodeDocument(document) {
    if (!document) return null;
    const name = document.name;
    return {
        id: name.split("/").pop(),
        name,
        ...fromFirestoreFields(document.fields),
        createTime: document.createTime,
        updateTime: document.updateTime
    };
}

function originAllowed(origin) {
    return [
        "https://www.starboundarcade.com",
        "https://starboundarcade.com",
        "http://localhost:6464",
        "http://127.0.0.1:6464"
    ].includes(origin);
}

function corsHeaders(origin) {
    return {
        "Access-Control-Allow-Origin": origin,
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Authorization, Content-Type",
        "Access-Control-Max-Age": "86400",
        "Vary": "Origin"
    };
}

function jsonResponse(body, status, origin) {
    return new Response(JSON.stringify(body), {
        status,
        headers: {
            "Content-Type": "application/json; charset=utf-8",
            "Cache-Control": "no-store",
            ...corsHeaders(origin)
        }
    });
}

async function verifyFirebaseToken(token, projectId) {
    const parts = token.split(".");
    if (parts.length !== 3) throw new ApiError(401, "Invalid sign-in token.");
    const header = decodeJwtPart(parts[0]);
    const claims = decodeJwtPart(parts[1]);
    if (header.alg !== "RS256" || typeof header.kid !== "string") {
        throw new ApiError(401, "Unsupported sign-in token.");
    }
    if (claims.aud !== projectId || claims.iss !== `https://securetoken.google.com/${projectId}`) {
        throw new ApiError(401, "Sign-in token is for a different Firebase project.");
    }
    const now = Math.floor(Date.now() / 1000);
    if (typeof claims.exp !== "number" || claims.exp <= now
        || typeof claims.iat !== "number" || claims.iat > now + 60
        || typeof claims.sub !== "string" || claims.sub.length === 0) {
        throw new ApiError(401, "Sign-in token has expired or is invalid.");
    }

    let keys = tokenCache.get("firebase-jwks");
    if (!keys || keys.expiresAt < now) {
        const response = await fetch(FIREBASE_JWKS_URL);
        if (!response.ok) throw new ApiError(502, "Could not verify Firebase sign-in.");
        const result = await response.json();
        keys = { value: result.keys, expiresAt: now + 3600 };
        tokenCache.set("firebase-jwks", keys);
    }
    const jwk = keys.value.find((key) => key.kid === header.kid);
    if (!jwk) {
        tokenCache.delete("firebase-jwks");
        throw new ApiError(401, "Sign-in token key is no longer valid. Sign in again.");
    }
    const publicKey = await crypto.subtle.importKey(
        "jwk",
        jwk,
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["verify"]
    );
    const valid = await crypto.subtle.verify(
        "RSASSA-PKCS1-v1_5",
        publicKey,
        decodeBase64Url(parts[2]),
        new TextEncoder().encode(`${parts[0]}.${parts[1]}`)
    );
    if (!valid) throw new ApiError(401, "Sign-in token signature is invalid.");
    return claims;
}

async function googleAccessToken(env) {
    const serviceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON || "{}");
    if (!serviceAccount.client_email || !serviceAccount.private_key) {
        throw new ApiError(500, "Cloudflare Worker is missing its Firestore service-account secret.");
    }
    const cached = tokenCache.get("google-access");
    if (cached && cached.expiresAt > Date.now() + 60_000) return cached.value;

    const now = Math.floor(Date.now() / 1000);
    const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
    const payload = base64UrlEncode(JSON.stringify({
        iss: serviceAccount.client_email,
        scope: GOOGLE_SCOPE,
        aud: GOOGLE_TOKEN_URL,
        iat: now,
        exp: now + 3600
    }));
    const unsigned = `${header}.${payload}`;
    const privateKey = await crypto.subtle.importKey(
        "pkcs8",
        pemToBytes(serviceAccount.private_key),
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"]
    );
    const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", privateKey, new TextEncoder().encode(unsigned));
    const assertion = `${unsigned}.${base64UrlEncode(new Uint8Array(signature))}`;
    const response = await fetch(GOOGLE_TOKEN_URL, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
            grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
            assertion
        })
    });
    if (!response.ok) throw new ApiError(502, "Could not authenticate the Firestore service.");
    const result = await response.json();
    tokenCache.set("google-access", { value: result.access_token, expiresAt: Date.now() + result.expires_in * 1000 });
    return result.access_token;
}

function documentPath(path, projectId) {
    const encodedPath = path.split("/").map(encodeURIComponent).join("/");
    return `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/databases/(default)/documents/${encodedPath}`;
}

function firestoreActionPath(action, projectId, parentPath = "") {
    const parent = parentPath ? `/${parentPath.split("/").map(encodeURIComponent).join("/")}` : "";
    return `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/databases/(default)/documents${parent}:${action}`;
}

async function firestoreRequest(path, projectId, accessToken, options = {}) {
    const response = await fetch(documentPath(path, projectId) + (options.query || ""), {
        method: options.method || "GET",
        headers: {
            Authorization: `Bearer ${accessToken}`,
            ...(options.body ? { "Content-Type": "application/json" } : {})
        },
        ...(options.body ? { body: JSON.stringify(options.body) } : {})
    });
    const text = await response.text();
    const result = text ? JSON.parse(text) : null;
    if (!response.ok) {
        const status = response.status === 409 ? 409 : response.status >= 500 ? 502 : response.status;
        throw new ApiError(status, result?.error?.message || `Firestore request failed (${response.status}).`);
    }
    return result;
}

async function firestoreAction(action, projectId, accessToken, body, parentPath = "") {
    const response = await fetch(firestoreActionPath(action, projectId, parentPath), {
        method: "POST",
        headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json"
        },
        body: JSON.stringify(body)
    });
    const text = await response.text();
    const result = text ? JSON.parse(text) : null;
    if (!response.ok) {
        const firestoreError = Array.isArray(result)
            ? result.find((entry) => entry?.error)?.error
            : result?.error || result;
        const errorMessage = firestoreError?.message || result?.message;
        console.error("Firestore action failed", {
            action,
            status: response.status,
            error: typeof errorMessage === "string" ? errorMessage : JSON.stringify(firestoreError || text.slice(0, 1000))
        });
        const status = response.status >= 500 ? 502 : response.status;
        throw new ApiError(status, errorMessage || `Firestore ${action} failed (${response.status}).`);
    }
    return result;
}

async function getDocument(path, projectId, accessToken) {
    try {
        return decodeDocument(await firestoreRequest(path, projectId, accessToken));
    } catch (error) {
        if (error instanceof ApiError && error.status === 404) return null;
        throw error;
    }
}

async function writeDocument(path, value, projectId, accessToken, { createOnly = false } = {}) {
    const query = createOnly ? "?currentDocument.exists=false" : "";
    return firestoreRequest(path, projectId, accessToken, {
        method: "PATCH",
        query,
        body: { fields: firestoreFields(value) }
    });
}

async function deleteDocument(path, projectId, accessToken) {
    await firestoreRequest(path, projectId, accessToken, { method: "DELETE" });
}

function collectionAddress(path, projectId) {
    if (!path) return { parentPath: "", collectionId: "" };
    const segments = path.split("/");
    const collectionId = segments.pop();
    return { parentPath: segments.join("/"), collectionId };
}

async function queryCollection(path, filters, projectId, accessToken, options = {}) {
    const { parentPath, collectionId } = collectionAddress(path, projectId);
    const structuredQuery = {
        from: [{ collectionId, ...(options.collectionGroup ? { allDescendants: true } : {}) }],
        ...(filters.length === 1 ? { where: filters[0] } : filters.length > 1 ? {
            where: { compositeFilter: { op: "AND", filters } }
        } : {}),
        ...(options.orderBy ? { orderBy: options.orderBy } : {}),
        ...(options.limit ? { limit: options.limit } : {})
    };
    const result = await firestoreAction("runQuery", projectId, accessToken, {
        structuredQuery,
        ...(options.transaction ? { transaction: options.transaction } : {})
    }, parentPath);
    return (result || []).filter((row) => row.document).map((row) => decodeDocument(row.document));
}

function fieldFilter(field, op, value) {
    return {
        fieldFilter: {
            field: { fieldPath: field },
            op,
            value: firestoreValue(value)
        }
    };
}

async function beginTransaction(projectId, accessToken) {
    return firestoreAction("beginTransaction", projectId, accessToken, { options: { readWrite: {} } });
}

async function commitTransaction(projectId, accessToken, transaction, writes) {
    return firestoreAction("commit", projectId, accessToken, { writes, transaction });
}

function firestoreWrite(path, value, projectId, updateMask) {
    const write = {
        update: {
            name: `projects/${projectId}/databases/(default)/documents/${path}`,
            fields: firestoreFields(value)
        }
    };
    if (updateMask?.length) write.updateMask = { fieldPaths: updateMask };
    return write;
}

async function runTransaction(projectId, accessToken, callback) {
    for (let attempt = 0; attempt < 5; attempt += 1) {
        const begun = await beginTransaction(projectId, accessToken);
        const writes = [];
        const tx = {
            get: async (path) => {
                const query = `?transaction=${encodeURIComponent(begun.transaction)}`;
                try {
                    return decodeDocument(await firestoreRequest(path, projectId, accessToken, { query }));
                } catch (error) {
                    if (error instanceof ApiError && error.status === 404) return null;
                    throw error;
                }
            },
            query: (path, filters, options = {}) => queryCollection(path, filters, projectId, accessToken, {
                ...options,
                transaction: begun.transaction
            }),
            create: (path, value) => writes.push({
                ...firestoreWrite(path, value, projectId),
                currentDocument: { exists: false }
            }),
            update: (path, value, fields) => writes.push(firestoreWrite(path, value, projectId, fields)),
            delete: (path) => writes.push({ delete: `projects/${projectId}/databases/(default)/documents/${path}` })
        };
        try {
            const result = await callback(tx);
            if (writes.length) await commitTransaction(projectId, accessToken, begun.transaction, writes);
            return result;
        } catch (error) {
            if (error instanceof ApiError && /ABORTED|transaction.*aborted/i.test(error.message) && attempt < 4) continue;
            throw error;
        }
    }
    throw new ApiError(409, "The database was busy. Please try again.");
}

function requiredText(value, name, maxLength) {
    if (typeof value !== "string") throw new ApiError(400, `${name} must be text.`);
    const text = value.trim();
    if (!text || text.length > maxLength) throw new ApiError(400, `${name} must be 1-${maxLength} characters.`);
    return text;
}

function requiredId(value, name, maxLength = 64) {
    const id = requiredText(value, name, maxLength);
    if (id.includes("/")) throw new ApiError(400, `${name} is not a valid ID.`);
    return id;
}

function safeId(value) {
    return crypto.subtle.digest("SHA-256", new TextEncoder().encode(value))
        .then((digest) => [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join(""));
}

async function activeUser(uid, claims, env, accessToken) {
    const path = `users/${uid}`;
    let user = await getDocument(path, env.PROJECT_ID, accessToken);
    if (!user) {
        user = {
            displayName: String(claims.name || "Player").slice(0, 32),
            status: "active",
            createdAt: timestampNow()
        };
        try {
            await writeDocument(path, user, env.PROJECT_ID, accessToken, { createOnly: true });
        } catch (error) {
            if (!(error instanceof ApiError && error.status === 409)) throw error;
        }
        user = await getDocument(path, env.PROJECT_ID, accessToken);
    }
    if (user.status !== "active") throw new ApiError(403, "This account cannot use the arcade.");
    user.publicId = await ensurePublicPlayerId(uid, user.publicId, env.PROJECT_ID, accessToken);
    if (!Number.isSafeInteger(user.levelsCreated) || !Number.isSafeInteger(user.totalPoints)) {
        const ownedGames = Number.isSafeInteger(user.levelsCreated)
            ? null
            : await queryCollection("games", [fieldFilter("ownerId", "EQUAL", uid)], env.PROJECT_ID, accessToken);
        const updates = {
            ...(!Number.isSafeInteger(user.levelsCreated) ? {
                levelsCreated: ownedGames.length
            } : {}),
            ...(!Number.isSafeInteger(user.totalPoints) ? { totalPoints: 0 } : {})
        };
        await firestoreRequest(path, env.PROJECT_ID, accessToken, {
            method: "PATCH",
            query: `?${Object.keys(updates).map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`).join("&")}`,
            body: { fields: firestoreFields(updates) }
        });
        Object.assign(user, updates);
    }
    return user;
}

async function ensurePublicPlayerId(uid, existingId, projectId, accessToken) {
    const userPath = `users/${uid}`;
    const validId = (value) => typeof value === "string" && /^[a-f0-9]{32}$/.test(value);
    if (validId(existingId)) return existingId;
    for (let attempt = 0; attempt < 5; attempt += 1) {
        const publicId = [...crypto.getRandomValues(new Uint8Array(16))]
            .map((byte) => byte.toString(16).padStart(2, "0")).join("");
        const result = await runTransaction(projectId, accessToken, async (tx) => {
            const user = await tx.get(userPath);
            if (!user) throw new ApiError(404, "Player profile not found.");
            if (validId(user.publicId)) return user.publicId;
            const currentId = publicId;
            const mappingPath = `publicPlayerIds/${currentId}`;
            const mapping = await tx.get(mappingPath);
            if (mapping && mapping.userId !== uid) return null;
            if (!mapping) tx.create(mappingPath, { userId: uid, createdAt: timestampNow() });
            if (user.publicId !== currentId) tx.update(userPath, { publicId: currentId }, ["publicId"]);
            return currentId;
        });
        if (result) return result;
    }
    throw new ApiError(503, "Could not assign a unique player link. Please try again.");
}

function gameConfig(input) {
    if (!input || typeof input !== "object" || Array.isArray(input)) {
        throw new ApiError(400, "Choose a game template and supported settings.");
    }
    if (!GAME_TYPES.has(input.gameType)) throw new ApiError(400, "Choose a supported game template.");
    const difficulty = ["easy", "normal", "hard"].includes(input.difficulty) ? input.difficulty : "normal";
    const accent = /^#[0-9a-fA-F]{6}$/.test(input.accent) ? input.accent.toLowerCase() : "#a78bfa";
    const pattern = Array.isArray(input.pattern) ? input.pattern.map((step) => step === "spike" ? "spike" : "empty").slice(0, 24) : [];
    return { gameType: input.gameType, difficulty, accent, pattern: input.gameType === "dash" ? pattern : [] };
}

function season() {
    return new Date().toISOString().slice(0, 10);
}

function timestampNow() {
    return { $timestamp: new Date().toISOString() };
}

function timestampAt(milliseconds) {
    return { $timestamp: new Date(milliseconds).toISOString() };
}

async function publishGame(data, uid, user, env, accessToken) {
    const title = requiredText(data.title || data.levelName, "Title", 48);
    const description = requiredText(data.description, "Description", 240);
    const rawLevelId = requiredText(data.levelId ?? data.id, "Level ID", 12);
    if (!/^\d+$/.test(rawLevelId)) throw new ApiError(400, "Level ID must contain only numerals (0-9).");
    const levelId = Number(rawLevelId);
    if (!Number.isSafeInteger(levelId)) throw new ApiError(400, "Level ID must be a valid whole number.");
    const levelName = requiredText(data.levelName || title, "Level name", 48);
    const config = gameConfig(data.config);
    const path = `games/${crypto.randomUUID().replace(/-/g, "").slice(0, 20)}`;
    await runTransaction(env.PROJECT_ID, accessToken, async (tx) => {
        const duplicates = await tx.query("games", [
            fieldFilter("levelId", "EQUAL", levelId),
        ], { limit: 1 });
        if (duplicates.length) throw new ApiError(409, "That Level ID is already in use. Pick a different numeric ID.");
        const userPath = `users/${uid}`;
        const profile = await tx.get(userPath);
        if (!profile || profile.status !== "active") throw new ApiError(403, "This account cannot publish levels.");
        tx.create(path, {
            ownerId: uid,
            ownerName: String(user.displayName || "Player").slice(0, 32),
            title: levelName,
            levelName,
            levelId,
            titleSearch: levelName.toLocaleLowerCase(),
            description,
            config,
            status: "published",
            reportCount: 0,
            createdAt: timestampNow(),
            updatedAt: timestampNow()
        });
        tx.update(userPath, { levelsCreated: (profile.levelsCreated || 0) + 1 }, ["levelsCreated"]);
    });
    return { id: path.split("/").pop(), levelId };
}

async function searchGames(data, env, accessToken) {
    const query = requiredText(data.query, "Search", 48);
    if (/^\d+$/.test(query)) {
        const levelId = Number(query);
        const games = await queryCollection("games", [
            fieldFilter("status", "EQUAL", "published"),
            fieldFilter("levelId", "EQUAL", levelId)
        ], env.PROJECT_ID, accessToken, { limit: 20 });
        return { games };
    }
    if (/^[a-zA-Z0-9]{20}$/.test(query)) {
        const game = await getDocument(`games/${query}`, env.PROJECT_ID, accessToken);
        return { games: game?.status === "published" ? [game] : [] };
    }
    const normalized = query.toLocaleLowerCase();
    const games = await queryCollection("games", [
        fieldFilter("status", "EQUAL", "published"),
        fieldFilter("titleSearch", "GREATER_THAN_OR_EQUAL", normalized),
        fieldFilter("titleSearch", "LESS_THAN_OR_EQUAL", `${normalized}\uf8ff`)
    ], env.PROJECT_ID, accessToken, {
        orderBy: [{ field: { fieldPath: "titleSearch" }, direction: "ASCENDING" }],
        limit: 20
    });
    return { games };
}

async function addComment(data, uid, user, env, accessToken) {
    const gameId = requiredId(data.gameId, "Game ID", 32);
    const text = requiredText(data.text, "Comment", 300);
    const game = await getDocument(`games/${gameId}`, env.PROJECT_ID, accessToken);
    if (!game || game.status !== "published") throw new ApiError(404, "That game is not available.");
    const status = /(?:https?:\/\/|www\.)/i.test(text) ? "pending" : "visible";
    const commentId = crypto.randomUUID().replace(/-/g, "");
    await writeDocument(`games/${gameId}/comments/${commentId}`, {
        userId: uid,
        displayName: String(user.displayName || "Player").slice(0, 32),
        text,
        status,
        reportCount: 0,
        createdAt: timestampNow()
    }, env.PROJECT_ID, accessToken, { createOnly: true });
    return { status };
}

async function reportContent(data, uid, env, accessToken) {
    const type = data.type;
    if (!["game", "comment", "user"].includes(type)) throw new ApiError(400, "Choose game, comment, or user content.");
    const contentId = requiredId(data.contentId, "Content ID", 64);
    const reason = requiredText(data.reason, "Reason", 200);
    const reportId = await safeId(`${type}_${contentId}_${uid}`);
    await runTransaction(env.PROJECT_ID, accessToken, async (tx) => {
        if (await tx.get(`reports/${reportId}`)) throw new ApiError(409, "You already reported this content.");
        tx.create(`reports/${reportId}`, {
            reporterId: uid,
            type,
            contentId,
            gameId: type === "comment" ? requiredId(data.gameId, "Game ID", 32) : null,
            reason,
            status: "open",
            createdAt: timestampNow()
        });
    });
    return { reported: true };
}

async function joinMatchmaking(data, uid, env, accessToken) {
    const gameId = requiredText(data.gameId, "Game", 20);
    const mode = data.mode;
    if (gameId !== "catch" || !MATCH_MODES.has(mode)) throw new ApiError(400, "Choose Star Catcher and a supported match mode.");
    const queueId = crypto.randomUUID().replace(/-/g, "");
    const result = await runTransaction(env.PROJECT_ID, accessToken, async (tx) => {
        const ownWaiting = await tx.query("matchmaking", [
            fieldFilter("gameId", "EQUAL", gameId),
            fieldFilter("mode", "EQUAL", mode),
            fieldFilter("status", "EQUAL", "waiting"),
            fieldFilter("playerId", "EQUAL", uid)
        ], { limit: 5 });
        for (const queued of ownWaiting) {
            tx.update(`matchmaking/${queued.id}`, { status: "cancelled" }, ["status"]);
        }
        const waiting = await tx.query("matchmaking", [
            fieldFilter("gameId", "EQUAL", gameId),
            fieldFilter("mode", "EQUAL", mode),
            fieldFilter("status", "EQUAL", "waiting"),
            fieldFilter("createdAt", "GREATER_THAN_OR_EQUAL", timestampAt(Date.now() - 60_000))
        ], {
            orderBy: [{ field: { fieldPath: "createdAt" }, direction: "ASCENDING" }],
            limit: 10
        });
        const opponent = waiting.find((entry) => entry.playerId !== uid);
        const createdAt = timestampNow();
        if (!opponent) {
            tx.create(`matchmaking/${queueId}`, { playerId: uid, gameId, mode, status: "waiting", createdAt });
            return { queueId, status: "waiting" };
        }
        const matchId = crypto.randomUUID().replace(/-/g, "");
        const opponentUid = opponent.playerId;
        tx.update(`matchmaking/${opponent.id}`, { status: "matched", matchId }, ["status", "matchId"]);
        tx.create(`matchmaking/${queueId}`, { playerId: uid, gameId, mode, status: "matched", matchId, createdAt });
        const now = Date.now();
        tx.create(`matches/${matchId}`, {
            gameId,
            mode,
            playerIds: [opponentUid, uid],
            players: {
                [opponentUid]: { x: 3, y: 3, score: 0, lastActionAt: 0 },
                [uid]: { x: 3, y: 3, score: 0, lastActionAt: 0 }
            },
            target: { x: 1 + Math.floor(Math.random() * 5), y: 1 + Math.floor(Math.random() * 5) },
            status: "playing",
            startedAt: { $timestamp: new Date(now).toISOString() },
            endsAt: { $timestamp: new Date(now + MATCH_SECONDS * 1000).toISOString() },
            createdAt
        });
        return { queueId, matchId, status: "matched" };
    });
    return result;
}

async function leaveMatchmaking(data, uid, env, accessToken) {
    const queueId = requiredId(data.queueId, "Queue ID", 32);
    await runTransaction(env.PROJECT_ID, accessToken, async (tx) => {
        const queue = await tx.get(`matchmaking/${queueId}`);
        if (queue && queue.playerId === uid && queue.status === "waiting") {
            tx.update(`matchmaking/${queueId}`, { status: "cancelled" }, ["status"]);
        }
    });
    return { left: true };
}

async function leaveMatch(data, uid, env, accessToken) {
    const matchId = requiredId(data.matchId, "Match ID", 32);
    await runTransaction(env.PROJECT_ID, accessToken, async (tx) => {
        const match = await tx.get(`matches/${matchId}`);
        if (!match || !match.playerIds.includes(uid)) throw new ApiError(403, "You are not in this match.");
        if (match.status === "playing") {
            tx.update(`matches/${matchId}`, {
                status: "complete",
                winnerId: match.playerIds.find((playerId) => playerId !== uid) || null,
                endedBy: uid,
                completedAt: timestampNow()
            }, ["status", "winnerId", "endedBy", "completedAt"]);
        }
    });
    return { left: true };
}

async function submitMatchMove(data, uid, user, env, accessToken) {
    const matchId = requiredId(data.matchId, "Match ID", 32);
    const direction = data.direction;
    if (!["up", "down", "left", "right"].includes(direction)) throw new ApiError(400, "Invalid move.");
    return runTransaction(env.PROJECT_ID, accessToken, async (tx) => {
        const match = await tx.get(`matches/${matchId}`);
        if (!match) throw new ApiError(404, "Match not found.");
        if (!match.playerIds.includes(uid)) throw new ApiError(403, "You are not in this match.");
        if (match.status !== "playing") return { status: match.status };
        const now = Date.now();
        if (now >= Date.parse(match.endsAt)) {
            tx.update(`matches/${matchId}`, { status: "complete", completedAt: { $timestamp: new Date(now).toISOString() } }, ["status", "completedAt"]);
            return { status: "complete" };
        }
        const player = match.players[uid];
        if (now - player.lastActionAt < MOVE_INTERVAL_MS) throw new ApiError(429, "Moves are arriving too quickly.");
        const offsets = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] };
        const [dx, dy] = offsets[direction];
        const x = (player.x + dx + 7) % 7;
        const y = (player.y + dy + 7) % 7;
        let score = player.score;
        let target = match.target;
        if (x === target.x && y === target.y) {
            score += 1;
            target = { x: Math.floor(Math.random() * 7), y: Math.floor(Math.random() * 7) };
        }
        const players = { ...match.players, [uid]: { x, y, score, lastActionAt: now } };
        let profile;
        if (score > player.score && match.mode === "ranked") {
            profile = await tx.get(`users/${uid}`);
            if (!profile || profile.status !== "active") throw new ApiError(403, "This account cannot earn ranked points.");
        }
        tx.update(`matches/${matchId}`, { players, target, updatedAt: { $timestamp: new Date(now).toISOString() } }, ["players", "target", "updatedAt"]);
        if (profile) {
            tx.update(`users/${uid}`, { totalPoints: (profile.totalPoints || 0) + score - player.score }, ["totalPoints"]);
        }
        if (score > player.score && match.mode === "ranked") {
            const boardId = `${match.gameId}_${match.mode}_${season()}`;
            const scorePath = `leaderboards/${boardId}/scores/${uid}`;
            const oldScore = await tx.get(scorePath);
            if (!oldScore || oldScore.score < score) {
                const scoreData = {
                    userId: uid,
                    displayName: String(user.displayName || "Player").slice(0, 32),
                    score,
                    updatedAt: timestampAt(now)
                };
                if (oldScore) tx.update(scorePath, scoreData, ["userId", "displayName", "score", "updatedAt"]);
                else tx.create(scorePath, scoreData);
            }
        }
        return { status: "playing", player: { x, y, score }, target, players };
    });
}

async function submitSoloScore(data, uid, user, env, accessToken) {
    const gameId = requiredId(data.gameId, "Game ID", 16);
    if (!GAME_TYPES.has(gameId)) throw new ApiError(400, "Choose a supported arcade game.");
    const { score, elapsedSeconds } = data;
    if (!Number.isSafeInteger(score) || score < 1 || score > 1_000_000_000) {
        throw new ApiError(400, "Score must be a whole number between 1 and 1,000,000,000.");
    }
    if (!Number.isSafeInteger(elapsedSeconds) || elapsedSeconds < 1 || elapsedSeconds > 1_000_000_000) {
        throw new ApiError(400, "Elapsed time must be a whole number between 1 and 1,000,000,000 seconds.");
    }

    return runTransaction(env.PROJECT_ID, accessToken, async (tx) => {
        const [profile, previous] = await Promise.all([
            tx.get(`users/${uid}`),
            tx.get(`leaderboards/solo_${gameId}_alltime/scores/${uid}`)
        ]);
        if (!profile || profile.status !== "active") {
            throw new ApiError(403, "This account cannot submit arcade scores.");
        }
        const isBest = !previous || score > previous.score
            || (score === previous.score && elapsedSeconds < previous.elapsedSeconds);
        if (!isBest) return { updated: false };
        const scorePath = `leaderboards/solo_${gameId}_alltime/scores/${uid}`;
        const scoreData = {
            userId: uid,
            gameId,
            displayName: String(user.displayName || "Player").slice(0, 32),
            score,
            elapsedSeconds,
            updatedAt: timestampNow()
        };
        if (previous) tx.update(scorePath, scoreData);
        else tx.create(scorePath, scoreData);
        return { updated: true };
    });
}

async function deleteAccount(uid, user, idToken, env, accessToken) {
    const projectId = env.PROJECT_ID;
    const paths = new Set([`users/${uid}`]);
    const [ownedGames, comments, scores, queues, reports, matches] = await Promise.all([
        queryCollection("games", [fieldFilter("ownerId", "EQUAL", uid)], projectId, accessToken),
        queryCollection("comments", [fieldFilter("userId", "EQUAL", uid)], projectId, accessToken, { collectionGroup: true }),
        queryCollection("scores", [fieldFilter("userId", "EQUAL", uid)], projectId, accessToken, { collectionGroup: true }),
        queryCollection("matchmaking", [fieldFilter("playerId", "EQUAL", uid)], projectId, accessToken),
        queryCollection("reports", [fieldFilter("reporterId", "EQUAL", uid)], projectId, accessToken),
        queryCollection("matches", [fieldFilter("playerIds", "ARRAY_CONTAINS", uid)], projectId, accessToken)
    ]);
    for (const game of ownedGames) {
        paths.add(`games/${game.id}`);
        const gameComments = await queryCollection(`games/${game.id}/comments`, [], projectId, accessToken);
        gameComments.forEach((comment) => paths.add(`games/${game.id}/comments/${comment.id}`));
    }
    comments.forEach((comment) => paths.add(comment.name.split("/documents/")[1]));
    scores.forEach((score) => paths.add(score.name.split("/documents/")[1]));
    queues.forEach((queue) => paths.add(`matchmaking/${queue.id}`));
    reports.forEach((report) => paths.add(`reports/${report.id}`));
    matches.forEach((match) => paths.add(`matches/${match.id}`));
    if (user.publicId) paths.add(`publicPlayerIds/${user.publicId}`);

    const documents = [...paths];
    for (let index = 0; index < documents.length; index += 100) {
        await Promise.all(documents.slice(index, index + 100).map((path) => deleteDocument(path, projectId, accessToken)));
    }

    if (!env.FIREBASE_API_KEY) throw new ApiError(500, "Account deletion is not configured. Contact the site administrator.");
    const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${encodeURIComponent(env.FIREBASE_API_KEY)}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ idToken })
    });
    const result = await response.json();
    if (!response.ok) {
        const code = result?.error?.message || "UNKNOWN";
        const message = code.includes("RECENT_LOGIN_REQUIRED")
            ? "Sign in again before deleting your account."
            : "Firebase could not delete this account. Please try signing out and back in.";
        throw new ApiError(response.status === 400 ? 401 : 502, message);
    }
    return { deleted: true };
}

function requireModerator(claims) {
    if (!(claims.moderator || claims.admin)) throw new ApiError(403, "Moderator access is required.");
}

async function dispatch(name, data, claims, user, env, accessToken, idToken) {
    const uid = claims.sub;
    switch (name) {
        case "updatePlayerProfile": {
            const displayName = requiredText(data.displayName, "Player name", 32);
            const path = `users/${uid}`;
            const current = await getDocument(path, env.PROJECT_ID, accessToken);
            const fields = { displayName, status: "active", updatedAt: timestampNow() };
            if (!current) fields.createdAt = timestampNow();
            await firestoreRequest(path, env.PROJECT_ID, accessToken, {
                method: "PATCH",
                query: `?${Object.keys(fields).map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`).join("&")}`,
                body: { fields: firestoreFields(fields) }
            });
            return { updated: true, publicId: user.publicId };
        }
        case "publishGame": return publishGame(data, uid, user, env, accessToken);
        case "searchGames": return searchGames(data, env, accessToken);
        case "addComment": return addComment(data, uid, user, env, accessToken);
        case "reportContent": return reportContent(data, uid, env, accessToken);
        case "joinMatchmaking": return joinMatchmaking(data, uid, env, accessToken);
        case "leaveMatchmaking": return leaveMatchmaking(data, uid, env, accessToken);
        case "leaveMatch": return leaveMatch(data, uid, env, accessToken);
        case "submitMatchMove": return submitMatchMove(data, uid, user, env, accessToken);
        case "getArcadeLeaderboard": {
            const gameId = requiredId(data.gameId, "Game ID", 16);
            if (!GAME_TYPES.has(gameId)) throw new ApiError(400, "Choose a supported arcade game.");
            const entries = await queryCollection(`leaderboards/solo_${gameId}_alltime/scores`, [], env.PROJECT_ID, accessToken, {
                orderBy: [{ field: { fieldPath: "score" }, direction: "DESCENDING" }],
                limit: 30
            });
            return {
                entries: entries.map((entry) => ({
                    displayName: String(entry.displayName || "Player").slice(0, 32),
                    score: Number.isSafeInteger(entry.score) ? entry.score : 0,
                    elapsedSeconds: Number.isSafeInteger(entry.elapsedSeconds) ? entry.elapsedSeconds : 0
                }))
            };
        }
        case "submitSoloScore": return submitSoloScore(data, uid, user, env, accessToken);
        case "getArcadeSchedule": {
            const today = new Date();
            const epochDay = Math.floor(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()) / 86_400_000);
            const dailyGames = ["catch", "dodge", "hop"];
            const weeklyGames = ["hop", "catch", "dodge"];
            const week = Math.floor(epochDay / 7);
            const event = today.getUTCDate() <= 7 ? "Nebula Sprint" : today.getUTCDate() <= 14 ? "Meteor Festival" : today.getUTCDate() <= 21 ? "Planet Hopping Cup" : "Starlight Showdown";
            return {
                daily: { gameId: dailyGames[epochDay % dailyGames.length], date: today.toISOString().slice(0, 10) },
                weekly: { gameId: weeklyGames[week % weeklyGames.length], week },
                event: { title: event, gameId: weeklyGames[(week + 1) % weeklyGames.length] }
            };
        }
        case "getCommunityLeaderboards": {
            const [creators, global] = await Promise.all([
                queryCollection("users", [], env.PROJECT_ID, accessToken, {
                    orderBy: [{ field: { fieldPath: "levelsCreated" }, direction: "DESCENDING" }],
                    limit: 100
                }),
                queryCollection("users", [], env.PROJECT_ID, accessToken, {
                    orderBy: [{ field: { fieldPath: "totalPoints" }, direction: "DESCENDING" }],
                    limit: 100
                })
            ]);
            const toEntry = (entry, value) => ({
                displayName: String(entry.displayName || "Player").slice(0, 32),
                value: Number.isSafeInteger(entry[value]) ? entry[value] : 0
            });
            const activeEntries = (entries, field) => entries
                .filter((entry) => entry.status === "active")
                .map((entry) => toEntry(entry, field))
                .filter((entry) => entry.value > 0)
                .slice(0, 30);
            return {
                creators: activeEntries(creators, "levelsCreated"),
                global: activeEntries(global, "totalPoints")
            };
        }
        case "deleteAccount": {
            if (!Number.isSafeInteger(claims.auth_time) || Date.now() / 1000 - claims.auth_time > 300) {
                throw new ApiError(401, "Sign in again before deleting your account.");
            }
            return deleteAccount(uid, user, idToken, env, accessToken);
        }
        case "getMatchState": {
            const queueId = requiredId(data.queueId, "Queue ID", 32);
            const queue = await getDocument(`matchmaking/${queueId}`, env.PROJECT_ID, accessToken);
            if (!queue || queue.playerId !== uid) throw new ApiError(404, "Matchmaking request not found.");
            return { status: queue.status, matchId: queue.matchId || null };
        }
        case "completeExpiredMatch": {
            const matchId = requiredId(data.matchId, "Match ID", 32);
            await runTransaction(env.PROJECT_ID, accessToken, async (tx) => {
                const match = await tx.get(`matches/${matchId}`);
                if (!match || !match.playerIds.includes(uid)) throw new ApiError(403, "You are not in this match.");
                if (match.status === "playing" && Date.now() >= Date.parse(match.endsAt)) {
                    tx.update(`matches/${matchId}`, { status: "complete", completedAt: timestampNow() }, ["status", "completedAt"]);
                }
            });
            const result = await getDocument(`matches/${matchId}`, env.PROJECT_ID, accessToken);
            return { status: result.status };
        }
        case "moderationQueue": {
            await requireModerator(claims);
            const reports = await queryCollection("reports", [
                fieldFilter("status", "EQUAL", "open")
            ], env.PROJECT_ID, accessToken, {
                orderBy: [{ field: { fieldPath: "createdAt" }, direction: "DESCENDING" }],
                limit: 50
            });
            const pendingComments = await queryCollection("comments", [
                fieldFilter("status", "EQUAL", "pending")
            ], env.PROJECT_ID, accessToken, { limit: 20, collectionGroup: true });
            return {
                reports: [
                    ...reports,
                    ...pendingComments.map((comment) => ({
                        contentId: comment.id,
                        gameId: comment.name.split("/").at(-3),
                        type: "comment",
                        reason: "Comment is awaiting review.",
                        isPending: true
                    }))
                ]
            };
        }
        case "moderateContent": {
            await requireModerator(claims);
            const type = data.type;
            const contentId = requiredId(data.contentId, "Content ID", 64);
            const action = data.action;
            let path;
            let updates;
            if (type === "comment" && ["approve", "remove"].includes(action)) {
                const gameId = requiredId(data.gameId, "Game ID", 32);
                path = `games/${gameId}/comments/${contentId}`;
                updates = { status: action === "approve" ? "visible" : "removed" };
            } else if (type === "game" && ["remove", "restore"].includes(action)) {
                path = `games/${contentId}`;
                updates = { status: action === "remove" ? "removed" : "published" };
            } else if (type === "user" && ["suspend", "restore"].includes(action)) {
                path = `users/${contentId}`;
                updates = { status: action === "suspend" ? "suspended" : "active" };
            } else {
                throw new ApiError(400, "That moderation action is not supported.");
            }
            const current = await getDocument(path, env.PROJECT_ID, accessToken);
            if (!current) throw new ApiError(404, "That content is no longer available.");
            const fields = Object.keys(updates);
            Object.assign(updates, { moderatedBy: uid, moderatedAt: timestampNow() });
            fields.push("moderatedBy", "moderatedAt");
            await firestoreRequest(path, env.PROJECT_ID, accessToken, {
                method: "PATCH",
                query: `?${fields.map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`).join("&")}`,
                body: { fields: firestoreFields(updates) }
            });
            if (typeof data.reportId === "string") {
                await firestoreRequest(`reports/${requiredId(data.reportId, "Report ID")}`, env.PROJECT_ID, accessToken, {
                    method: "PATCH",
                    query: "?updateMask.fieldPaths=status&updateMask.fieldPaths=reviewedBy&updateMask.fieldPaths=reviewedAt",
                    body: { fields: firestoreFields({ status: "reviewed", reviewedBy: uid, reviewedAt: timestampNow() }) }
                });
            }
            return { moderated: true };
        }
        default:
            throw new ApiError(404, `Unknown arcade API operation: ${name}`);
    }
}

export default {
    async fetch(request, env) {
        const origin = request.headers.get("Origin") || "";
        const url = new URL(request.url);
        if (request.method === "GET" && url.pathname.endsWith("/health")) {
            return Response.json({ status: "ok", backend: "cloudflare-worker" }, {
                headers: { "Cache-Control": "no-store" }
            });
        }
        if (!originAllowed(origin)) return new Response("Origin not allowed.", { status: 403 });
        if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders(origin) });
        if (request.method !== "POST") return jsonResponse({ error: { message: "POST required." } }, 405, origin);

        try {
            const name = url.pathname.split("/").filter(Boolean).pop();
            const authorization = request.headers.get("Authorization") || "";
            const token = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
            if (!token) throw new ApiError(401, "Sign in to use the arcade.");

            const claims = await verifyFirebaseToken(token, env.PROJECT_ID);
            const body = await request.json();
            const data = body?.data || {};
            const accessToken = await googleAccessToken(env);
            const user = await activeUser(claims.sub, claims, env, accessToken);
            const result = await dispatch(name, data, claims, user, env, accessToken, token);
            return jsonResponse({ data: result }, 200, origin);
        } catch (error) {
            console.error("Arcade API request failed", {
                operation: url.pathname.split("/").filter(Boolean).pop(),
                error: error instanceof Error ? error.message : String(error)
            });
            const status = error instanceof ApiError ? error.status : 500;
            const message = error instanceof ApiError ? error.message : "The arcade service encountered an unexpected error.";
            return jsonResponse({ error: { message, status } }, status, origin);
        }
    }
};
