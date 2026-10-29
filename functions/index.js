const { initializeApp } = require("firebase-admin/app");
const { FieldValue, Timestamp, getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { createHash, randomBytes } = require("node:crypto");

initializeApp();
const db = getFirestore();
const firebaseAuth = getAuth();
const REGION = "us-central1";
const MATCH_SECONDS = 30;
const MOVE_INTERVAL_MS = 75;
const CALLABLE_OPTIONS = {
    region: REGION,
    cors: [
        "https://www.starboundarcade.com",
        "https://starboundarcade.com",
        "http://localhost:6464",
        "http://127.0.0.1:6464"
    ]
};
const GAME_TYPES = new Set(["catch", "dodge", "hop", "dash"]);
const MODES = new Set(["casual", "ranked"]);

function requireText(value, name, maxLength) {
    if (typeof value !== "string") {
        throw new HttpsError("invalid-argument", `${name} must be text.`);
    }
    const text = value.trim();
    if (!text || text.length > maxLength) {
        throw new HttpsError("invalid-argument", `${name} must be 1-${maxLength} characters.`);
    }
    return text;
}

function requireDocumentId(value, name, maxLength = 64) {
    const id = requireText(value, name, maxLength);
    if (id.includes("/")) {
        throw new HttpsError("invalid-argument", `${name} is not a valid ID.`);
    }
    return id;
}

function requireNumericLevelId(value) {
    const raw = requireText(value, "Level ID", 12);
    if (!/^\d+$/.test(raw)) {
        throw new HttpsError("invalid-argument", "Level ID must contain only numerals (0-9).");
    }
    const numeric = Number(raw);
    if (!Number.isSafeInteger(numeric) || numeric < 0) {
        throw new HttpsError("invalid-argument", "Level ID must be a valid whole number.");
    }
    return numeric;
}

async function requireActiveUser(request) {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Sign in to use the arcade.");
    }
    const userRef = db.collection("users").doc(request.auth.uid);
    let userSnapshot = await userRef.get();
    if (!userSnapshot.exists) {
        await db.runTransaction(async (transaction) => {
            const current = await transaction.get(userRef);
            if (!current.exists) {
                transaction.create(userRef, {
                    displayName: (request.auth.token.name || "Player").slice(0, 32),
                    status: "active",
                    createdAt: FieldValue.serverTimestamp()
                });
            }
        });
        userSnapshot = await userRef.get();
    }
    const user = userSnapshot.data();
    if (user.status !== "active") {
        throw new HttpsError("permission-denied", "This account cannot use the arcade.");
    }
    user.publicId = await ensurePublicPlayerId(userRef, user.publicId);
    if (!Number.isSafeInteger(user.levelsCreated) || !Number.isSafeInteger(user.totalPoints)) {
        const ownedGames = Number.isSafeInteger(user.levelsCreated)
            ? null
            : await db.collection("games").where("ownerId", "==", request.auth.uid).get();
        const updates = {
            ...(!Number.isSafeInteger(user.levelsCreated) ? {
                levelsCreated: ownedGames.size
            } : {}),
            ...(!Number.isSafeInteger(user.totalPoints) ? { totalPoints: 0 } : {})
        };
        await userRef.update(updates);
        Object.assign(user, updates);
    }

    return { uid: request.auth.uid, userRef, user };
}

async function ensurePublicPlayerId(userRef, existingId) {
    const validId = (value) => typeof value === "string" && /^[a-f0-9]{32}$/.test(value);
    if (validId(existingId)) return existingId;
    for (let attempt = 0; attempt < 5; attempt += 1) {
        const publicId = randomBytes(16).toString("hex");
        const result = await db.runTransaction(async (transaction) => {
            const userSnapshot = await transaction.get(userRef);
            if (!userSnapshot.exists) {
                throw new HttpsError("not-found", "Player profile not found.");
            }
            const user = userSnapshot.data();
            if (validId(user.publicId)) return user.publicId;
            const currentId = publicId;
            const mappingRef = db.collection("publicPlayerIds").doc(currentId);
            const mappingSnapshot = await transaction.get(mappingRef);
            if (mappingSnapshot.exists && mappingSnapshot.data().userId !== userRef.id) return null;
            if (!mappingSnapshot.exists) {
                transaction.create(mappingRef, {
                    userId: userRef.id,
                    createdAt: FieldValue.serverTimestamp()
                });
            }
            if (user.publicId !== currentId) transaction.update(userRef, { publicId: currentId });
            return currentId;
        });
        if (result) return result;
    }
    throw new HttpsError("unavailable", "Could not assign a unique player link. Please try again.");
}

function safeDocumentId(value) {
    return createHash("sha256").update(value).digest("hex");
}

function requireModerator(request) {
    if (!request.auth || !(request.auth.token.moderator || request.auth.token.admin)) {
        throw new HttpsError("permission-denied", "Moderator access is required.");
    }
}

function currentSeason() {
    return new Date().toISOString().slice(0, 10);
}

function cleanGameConfig(input) {
    if (!input || typeof input !== "object" || Array.isArray(input)) {
        throw new HttpsError("invalid-argument", "Choose a game template and supported settings.");
    }
    const gameType = input.gameType;
    if (!GAME_TYPES.has(gameType)) {
        throw new HttpsError("invalid-argument", "Choose a supported game template.");
    }
    const difficulty = ["easy", "normal", "hard"].includes(input.difficulty) ? input.difficulty : "normal";
    const accent = /^#[0-9a-fA-F]{6}$/.test(input.accent) ? input.accent.toLowerCase() : "#a78bfa";
    const pattern = Array.isArray(input.pattern)
        ? input.pattern.map((step) => (step === "spike" ? "spike" : "empty")).slice(0, 24)
        : [];
    return { gameType, difficulty, accent, pattern: gameType === "dash" ? pattern : [] };
}

exports.publishGame = onCall(CALLABLE_OPTIONS, async (request) => {
    const { uid, user } = await requireActiveUser(request);
    const title = requireText(request.data.title || request.data.levelName, "Title", 48);
    const description = requireText(request.data.description, "Description", 240);
    const levelId = requireNumericLevelId(request.data.levelId ?? request.data.id);
    const levelName = requireText(request.data.levelName || title, "Level name", 48);
    const config = cleanGameConfig(request.data.config);
    const gameRef = db.collection("games").doc();
    const userRef = db.collection("users").doc(uid);
    await db.runTransaction(async (transaction) => {
        const duplicateQuery = db.collection("games").where("levelId", "==", levelId).limit(1);
        const existing = await transaction.get(duplicateQuery);
        const userSnapshot = await transaction.get(userRef);
        if (!existing.empty) {
            throw new HttpsError("already-exists", "That Level ID is already in use. Pick a different numeric ID.");
        }
        if (!userSnapshot.exists || userSnapshot.data().status !== "active") {
            throw new HttpsError("permission-denied", "This account cannot publish levels.");
        }
        transaction.create(gameRef, {
            ownerId: uid,
            ownerName: (user.displayName || "Player").slice(0, 32),
            title: levelName,
            levelName,
            levelId,
            titleSearch: levelName.toLocaleLowerCase(),
            description,
            config,
            status: "published",
            reportCount: 0,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp()
        });
        transaction.update(userRef, { levelsCreated: (userSnapshot.data().levelsCreated || 0) + 1 });
    });
    return { id: gameRef.id, levelId };
});

exports.updatePlayerProfile = onCall(CALLABLE_OPTIONS, async (request) => {
    const { userRef, user } = await requireActiveUser(request);
    const displayName = requireText(request.data.displayName, "Player name", 32);
    await userRef.update({ displayName, updatedAt: FieldValue.serverTimestamp() });
    return { updated: true, publicId: user.publicId };
});

exports.getCommunityLeaderboards = onCall(CALLABLE_OPTIONS, async (request) => {
    await requireActiveUser(request);
    const [creators, global] = await Promise.all([
        db.collection("users").orderBy("levelsCreated", "desc").limit(100).get(),
        db.collection("users").orderBy("totalPoints", "desc").limit(100).get()
    ]);
    const entries = (snapshot, field) => snapshot.docs
        .filter((entry) => entry.data().status === "active")
        .map((entry) => ({
            displayName: String(entry.data().displayName || "Player").slice(0, 32),
            value: Number.isSafeInteger(entry.data()[field]) ? entry.data()[field] : 0
        }))
        .filter((entry) => entry.value > 0)
        .slice(0, 30);
    return { creators: entries(creators, "levelsCreated"), global: entries(global, "totalPoints") };
});

exports.getArcadeLeaderboard = onCall(CALLABLE_OPTIONS, async (request) => {
    await requireActiveUser(request);
    const gameId = request.data.gameId;
    if (!GAME_TYPES.has(gameId)) {
        throw new HttpsError("invalid-argument", "Choose a supported arcade game.");
    }
    const snapshot = await db.collection("leaderboards").doc(`solo_${gameId}_alltime`)
        .collection("scores").orderBy("score", "desc").limit(30).get();
    return {
        entries: snapshot.docs.map((entry) => {
            const score = entry.data();
            return {
                displayName: String(score.displayName || "Player").slice(0, 32),
                score: Number.isSafeInteger(score.score) ? score.score : 0,
                elapsedSeconds: Number.isSafeInteger(score.elapsedSeconds) ? score.elapsedSeconds : 0
            };
        })
    };
});

exports.submitSoloScore = onCall(CALLABLE_OPTIONS, async (request) => {
    const { uid, user } = await requireActiveUser(request);
    const gameId = request.data.gameId;
    const score = request.data.score;
    const elapsedSeconds = request.data.elapsedSeconds;
    if (!GAME_TYPES.has(gameId)) {
        throw new HttpsError("invalid-argument", "Choose a supported arcade game.");
    }
    if (!Number.isSafeInteger(score) || score < 1 || score > 1_000_000_000) {
        throw new HttpsError("invalid-argument", "Score must be a whole number between 1 and 1,000,000,000.");
    }
    if (!Number.isSafeInteger(elapsedSeconds) || elapsedSeconds < 1 || elapsedSeconds > 1_000_000_000) {
        throw new HttpsError("invalid-argument", "Elapsed time must be a whole number between 1 and 1,000,000,000 seconds.");
    }

    const scoreRef = db.collection("leaderboards").doc(`solo_${gameId}_alltime`).collection("scores").doc(uid);
    const userRef = db.collection("users").doc(uid);
    return db.runTransaction(async (transaction) => {
        const [profileSnapshot, scoreSnapshot] = await Promise.all([
            transaction.get(userRef),
            transaction.get(scoreRef)
        ]);
        if (!profileSnapshot.exists || profileSnapshot.data().status !== "active") {
            throw new HttpsError("permission-denied", "This account cannot submit arcade scores.");
        }
        const previous = scoreSnapshot.exists ? scoreSnapshot.data() : null;
        const isBest = !previous || score > previous.score
            || (score === previous.score && elapsedSeconds < previous.elapsedSeconds);
        if (!isBest) return { updated: false };
        transaction.set(scoreRef, {
            userId: uid,
            gameId,
            displayName: String(user.displayName || "Player").slice(0, 32),
            score,
            elapsedSeconds,
            updatedAt: FieldValue.serverTimestamp()
        });
        return { updated: true };
    });
});

async function deleteMatchingDocuments(query) {
    const snapshot = await query.get();
    for (let index = 0; index < snapshot.docs.length; index += 450) {
        const batch = db.batch();
        snapshot.docs.slice(index, index + 450).forEach((document) => batch.delete(document.ref));
        await batch.commit();
    }
}

exports.deleteAccount = onCall(CALLABLE_OPTIONS, async (request) => {
    const authTime = request.auth?.token.auth_time;
    if (!Number.isSafeInteger(authTime) || Date.now() / 1000 - authTime > 300) {
        throw new HttpsError("unauthenticated", "Sign in again before deleting your account.");
    }
    const { uid, user, userRef } = await requireActiveUser(request);
    const ownedGames = await db.collection("games").where("ownerId", "==", uid).get();
    for (const game of ownedGames.docs) {
        await db.recursiveDelete(game.ref);
    }
    await Promise.all([
        deleteMatchingDocuments(db.collectionGroup("comments").where("userId", "==", uid)),
        deleteMatchingDocuments(db.collectionGroup("scores").where("userId", "==", uid)),
        deleteMatchingDocuments(db.collection("matchmaking").where("playerId", "==", uid)),
        deleteMatchingDocuments(db.collection("reports").where("reporterId", "==", uid)),
        deleteMatchingDocuments(db.collection("matches").where("playerIds", "array-contains", uid)),
        user.publicId
            ? db.collection("publicPlayerIds").doc(user.publicId).delete()
            : Promise.resolve()
    ]);
    await userRef.delete();
    await firebaseAuth.deleteUser(uid);
    return { deleted: true };
});

exports.searchGames = onCall(CALLABLE_OPTIONS, async (request) => {
    await requireActiveUser(request);
    const query = requireText(request.data.query, "Search", 48);
    const games = db.collection("games");
    if (/^\d+$/.test(query)) {
        const numeric = Number(query);
        const snapshot = await games.where("status", "==", "published").where("levelId", "==", numeric).limit(20).get();
        return { games: snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })) };
    }
    if (/^[a-zA-Z0-9]{20}$/.test(query)) {
        const snapshot = await games.doc(query).get();
        const game = snapshot.data();
        if (!snapshot.exists || game.status !== "published") return { games: [] };
        return { games: [{ id: snapshot.id, ...game }] };
    }
    const normalized = query.toLocaleLowerCase();
    const snapshot = await games
        .where("status", "==", "published")
        .where("titleSearch", ">=", normalized)
        .where("titleSearch", "<=", `${normalized}\uf8ff`)
        .orderBy("titleSearch")
        .limit(20)
        .get();
    return { games: snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })) };
});

exports.addComment = onCall(CALLABLE_OPTIONS, async (request) => {
    const { uid, user } = await requireActiveUser(request);
    const gameId = requireDocumentId(request.data.gameId, "Game ID", 32);
    const text = requireText(request.data.text, "Comment", 300);
    const gameRef = db.collection("games").doc(gameId);
    const gameSnapshot = await gameRef.get();
    if (!gameSnapshot.exists || gameSnapshot.data().status !== "published") {
        throw new HttpsError("not-found", "That game is not available.");
    }
    const links = /(?:https?:\/\/|www\.)/i.test(text);
    await gameRef.collection("comments").add({
        userId: uid,
        displayName: (user.displayName || "Player").slice(0, 32),
        text,
        status: links ? "pending" : "visible",
        reportCount: 0,
        createdAt: FieldValue.serverTimestamp()
    });
    return { status: links ? "pending" : "visible" };
});

exports.onCommentCreated = onDocumentCreated({
    document: "games/{gameId}/comments/{commentId}",
    region: REGION
}, async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const comment = snapshot.data();
    const userSnapshot = await db.collection("users").doc(comment.userId).get();
    if (!userSnapshot.exists || userSnapshot.data().status !== "active") {
        await snapshot.ref.update({ status: "removed", moderatedAt: FieldValue.serverTimestamp() });
    }
});

exports.reportContent = onCall(CALLABLE_OPTIONS, async (request) => {
    const { uid } = await requireActiveUser(request);
    const type = request.data.type;
    const contentId = requireDocumentId(request.data.contentId, "Content ID", 64);
    const reason = requireText(request.data.reason, "Reason", 200);
    if (!["game", "comment", "user"].includes(type)) {
        throw new HttpsError("invalid-argument", "Choose game, comment, or user content.");
    }
    const reportRef = db.collection("reports").doc(safeDocumentId(`${type}_${contentId}_${uid}`));
    await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(reportRef);
        if (existing.exists) {
            throw new HttpsError("already-exists", "You already reported this content.");
        }
        transaction.create(reportRef, {
            reporterId: uid,
            type,
            contentId,
            gameId: type === "comment" ? requireDocumentId(request.data.gameId, "Game ID", 32) : null,
            reason,
            status: "open",
            createdAt: FieldValue.serverTimestamp()
        });
    });
    return { reported: true };
});

exports.moderateContent = onCall(CALLABLE_OPTIONS, async (request) => {
    await requireActiveUser(request);
    requireModerator(request);
    const type = request.data.type;
    const contentId = requireDocumentId(request.data.contentId, "Content ID", 64);
    const action = request.data.action;
    if (type === "comment" && ["approve", "remove"].includes(action)) {
        const gameId = requireDocumentId(request.data.gameId, "Game ID", 32);
        await db.collection("games").doc(gameId).collection("comments").doc(contentId).update({
            status: action === "approve" ? "visible" : "removed",
            moderatedBy: request.auth.uid,
            moderatedAt: FieldValue.serverTimestamp()
        });
    } else if (type === "game" && ["remove", "restore"].includes(action)) {
        await db.collection("games").doc(contentId).update({
            status: action === "remove" ? "removed" : "published",
            moderatedBy: request.auth.uid,
            moderatedAt: FieldValue.serverTimestamp()
        });
    } else if (type === "user" && ["suspend", "restore"].includes(action)) {
        await db.collection("users").doc(contentId).update({
            status: action === "suspend" ? "suspended" : "active",
            moderatedBy: request.auth.uid,
            moderatedAt: FieldValue.serverTimestamp()
        });
    } else {
        throw new HttpsError("invalid-argument", "That moderation action is not supported.");
    }
    if (typeof request.data.reportId === "string") {
        await db.collection("reports").doc(request.data.reportId).update({
            status: "reviewed",
            reviewedBy: request.auth.uid,
            reviewedAt: FieldValue.serverTimestamp()
        });
    }
    return { moderated: true };
});

exports.joinMatchmaking = onCall(CALLABLE_OPTIONS, async (request) => {
    const { uid } = await requireActiveUser(request);
    const gameId = requireText(request.data.gameId, "Game", 20);
    const mode = request.data.mode;
    if (gameId !== "catch" || !MODES.has(mode)) {
        throw new HttpsError("invalid-argument", "Choose Star Catcher and a supported match mode.");
    }
    const gameRef = db.collection("matchmaking").doc();
    const queue = db.collection("matchmaking");
    const ownQueue = queue
        .where("gameId", "==", gameId)
        .where("mode", "==", mode)
        .where("status", "==", "waiting")
        .where("playerId", "==", uid)
        .limit(5);
    const waitingQuery = queue
        .where("gameId", "==", gameId)
        .where("mode", "==", mode)
        .where("status", "==", "waiting")
        .where("createdAt", ">=", Timestamp.fromMillis(Date.now() - 60_000))
        .orderBy("createdAt")
        .limit(10);

    const result = await db.runTransaction(async (transaction) => {
        const ownWaiting = await transaction.get(ownQueue);
        const waiting = await transaction.get(waitingQuery);
        for (const queuedGame of ownWaiting.docs) {
            transaction.update(queuedGame.ref, { status: "cancelled" });
        }
        const opponentQueue = waiting.docs.find((doc) => doc.data().playerId !== uid);
        if (!opponentQueue) {
            transaction.create(gameRef, {
                playerId: uid,
                gameId,
                mode,
                status: "waiting",
                createdAt: FieldValue.serverTimestamp()
            });
            return { queueId: gameRef.id, status: "waiting" };
        }
        const opponentUid = opponentQueue.data().playerId;
        const matchRef = db.collection("matches").doc();
        const initialTarget = { x: 1 + Math.floor(Math.random() * 5), y: 1 + Math.floor(Math.random() * 5) };
        const now = Timestamp.now();
        transaction.update(opponentQueue.ref, { status: "matched", matchId: matchRef.id });
        transaction.create(gameRef, {
            playerId: uid,
            gameId,
            mode,
            status: "matched",
            matchId: matchRef.id,
            createdAt: FieldValue.serverTimestamp()
        });
        transaction.create(matchRef, {
            gameId,
            mode,
            playerIds: [opponentUid, uid],
            players: {
                [opponentUid]: { x: 3, y: 3, score: 0, lastActionAt: 0 },
                [uid]: { x: 3, y: 3, score: 0, lastActionAt: 0 }
            },
            target: initialTarget,
            status: "playing",
            startedAt: now,
            endsAt: Timestamp.fromMillis(now.toMillis() + MATCH_SECONDS * 1000),
            createdAt: FieldValue.serverTimestamp()
        });
        return { queueId: gameRef.id, matchId: matchRef.id, status: "matched" };
    });
    return result;
});

exports.leaveMatchmaking = onCall(CALLABLE_OPTIONS, async (request) => {
    const { uid } = await requireActiveUser(request);
    const queueId = requireDocumentId(request.data.queueId, "Queue ID", 32);
    const queueRef = db.collection("matchmaking").doc(queueId);
    await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(queueRef);
        if (snapshot.exists && snapshot.data().playerId === uid && snapshot.data().status === "waiting") {
            transaction.update(queueRef, { status: "cancelled" });
        }
    });
    return { left: true };
});

exports.leaveMatch = onCall(CALLABLE_OPTIONS, async (request) => {
    const { uid } = await requireActiveUser(request);
    const matchId = requireDocumentId(request.data.matchId, "Match ID", 32);
    const matchRef = db.collection("matches").doc(matchId);
    await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(matchRef);
        if (!snapshot.exists || !snapshot.data().playerIds.includes(uid)) {
            throw new HttpsError("permission-denied", "You are not in this match.");
        }
        const match = snapshot.data();
        if (match.status === "playing") {
            const winnerId = match.playerIds.find((playerId) => playerId !== uid) || null;
            transaction.update(matchRef, {
                status: "complete",
                winnerId,
                endedBy: uid,
                completedAt: FieldValue.serverTimestamp()
            });
        }
    });
    return { left: true };
});

exports.submitMatchMove = onCall(CALLABLE_OPTIONS, async (request) => {
    const { uid, user } = await requireActiveUser(request);
    const matchId = requireDocumentId(request.data.matchId, "Match ID", 32);
    const direction = request.data.direction;
    if (!["up", "down", "left", "right"].includes(direction)) {
        throw new HttpsError("invalid-argument", "Invalid move.");
    }
    const matchRef = db.collection("matches").doc(matchId);
    const now = Timestamp.now();
    const result = await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(matchRef);
        if (!snapshot.exists) throw new HttpsError("not-found", "Match not found.");
        const match = snapshot.data();
        if (!match.playerIds.includes(uid)) throw new HttpsError("permission-denied", "You are not in this match.");
        if (match.status !== "playing") return { status: match.status };
        if (now.toMillis() >= match.endsAt.toMillis()) {
            transaction.update(matchRef, { status: "complete", completedAt: now });
            return { status: "complete" };
        }
        const player = match.players[uid];
        if (now.toMillis() - player.lastActionAt < MOVE_INTERVAL_MS) {
            throw new HttpsError("resource-exhausted", "Moves are arriving too quickly.");
        }
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
        const players = {
            ...match.players,
            [uid]: { x, y, score, lastActionAt: now.toMillis() }
        };
        let leaderboardRef;
        let leaderboardSnapshot;
        let profileRef;
        let profileSnapshot;
        if (score > player.score && match.mode === "ranked") {
            const boardId = `${match.gameId}_${match.mode}_${currentSeason()}`;
            leaderboardRef = db.collection("leaderboards").doc(boardId).collection("scores").doc(uid);
            profileRef = db.collection("users").doc(uid);
            [leaderboardSnapshot, profileSnapshot] = await Promise.all([
                transaction.get(leaderboardRef),
                transaction.get(profileRef)
            ]);
            if (!profileSnapshot.exists || profileSnapshot.data().status !== "active") {
                throw new HttpsError("permission-denied", "This account cannot earn ranked points.");
            }
        }
        transaction.update(matchRef, { players, target, updatedAt: now });
        if (profileRef) {
            transaction.update(profileRef, { totalPoints: (profileSnapshot.data().totalPoints || 0) + score - player.score });
        }
        if (leaderboardRef && (!leaderboardSnapshot.exists || leaderboardSnapshot.data().score < score)) {
            transaction.set(leaderboardRef, {
                userId: uid,
                displayName: (user.displayName || "Player").slice(0, 32),
                score,
                updatedAt: now
            }, { merge: true });
        }
        return { status: "playing", player: { x, y, score }, target, players };
    });
    return result;
});

exports.getArcadeSchedule = onCall(CALLABLE_OPTIONS, async (request) => {
    await requireActiveUser(request);
    const today = new Date();
    const epochDay = Math.floor(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()) / 86_400_000);
    const dailyGames = ["catch", "dodge", "hop"];
    const daily = dailyGames[epochDay % dailyGames.length];
    const weeklyGames = ["hop", "catch", "dodge"];
    const week = Math.floor(epochDay / 7);
    const event = today.getUTCDate() <= 7 ? "Nebula Sprint" : today.getUTCDate() <= 14 ? "Meteor Festival" : today.getUTCDate() <= 21 ? "Planet Hopping Cup" : "Starlight Showdown";
    return {
        daily: { gameId: daily, date: today.toISOString().slice(0, 10) },
        weekly: { gameId: weeklyGames[week % weeklyGames.length], week },
        event: { title: event, gameId: weeklyGames[(week + 1) % weeklyGames.length] }
    };
});

exports.moderationQueue = onCall(CALLABLE_OPTIONS, async (request) => {
    await requireActiveUser(request);
    requireModerator(request);
    const reports = await db.collection("reports").where("status", "==", "open").orderBy("createdAt", "desc").limit(50).get();
    const pendingComments = await db.collectionGroup("comments").where("status", "==", "pending").limit(20).get();
    return {
        reports: [
            ...reports.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
            ...pendingComments.docs.map((doc) => ({
                contentId: doc.id,
                gameId: doc.ref.parent.parent.id,
                type: "comment",
                reason: "Comment is awaiting review.",
                isPending: true
            }))
        ]
    };
});

exports.getMatchState = onCall(CALLABLE_OPTIONS, async (request) => {
    const { uid } = await requireActiveUser(request);
    const queueId = requireDocumentId(request.data.queueId, "Queue ID", 32);
    const queueSnapshot = await db.collection("matchmaking").doc(queueId).get();
    if (!queueSnapshot.exists || queueSnapshot.data().playerId !== uid) {
        throw new HttpsError("not-found", "Matchmaking request not found.");
    }
    return { status: queueSnapshot.data().status, matchId: queueSnapshot.data().matchId || null };
});

exports.completeExpiredMatch = onCall(CALLABLE_OPTIONS, async (request) => {
    const { uid } = await requireActiveUser(request);
    const matchId = requireDocumentId(request.data.matchId, "Match ID", 32);
    const matchRef = db.collection("matches").doc(matchId);
    await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(matchRef);
        if (!snapshot.exists || !snapshot.data().playerIds.includes(uid)) {
            throw new HttpsError("permission-denied", "You are not in this match.");
        }
        if (snapshot.data().status === "playing" && Timestamp.now().toMillis() >= snapshot.data().endsAt.toMillis()) {
            transaction.update(matchRef, { status: "complete", completedAt: FieldValue.serverTimestamp() });
        }
    });
    const result = await matchRef.get();
    return { status: result.data().status };
});
