import {
    EmailAuthProvider,
    onAuthStateChanged,
    reauthenticateWithCredential,
    signOut
} from "https://www.gstatic.com/firebasejs/13.0.0/firebase-auth.js";
import {
    collection,
    doc,
    limit,
    onSnapshot,
    orderBy,
    query,
    where
} from "https://www.gstatic.com/firebasejs/13.0.0/firebase-firestore.js";
import { httpsCallable } from "https://www.gstatic.com/firebasejs/13.0.0/firebase-functions.js";
import { auth, db, functions } from "./firebase.js";
import { syncPlayerLink } from "./player-links.js";

const loading = document.getElementById("community-loading");
const app = document.getElementById("community-app");
const tabs = [...document.querySelectorAll(".hub-tab")];
async function call(name, data = {}) {
    if (["localhost", "127.0.0.1", "::1"].includes(window.location.hostname)) {
        return httpsCallable(functions, name)(data);
    }

    const user = auth.currentUser;
    if (!user) {
        const error = new Error("Sign in to use the arcade.");
        error.code = "functions/unauthenticated";
        throw error;
    }
    const response = await fetch(`/api/${encodeURIComponent(name)}`, {
        method: "POST",
        headers: {
            Authorization: `Bearer ${await user.getIdToken()}`,
            "Content-Type": "application/json"
        },
        body: JSON.stringify({ data })
    });
    let result;
    try {
        result = await response.json();
    } catch {
        throw new Error(`The online backend returned an unreadable response (${response.status}). Check that Cloudflare routes /api/* to the arcade Worker.`);
    }
    if (!response.ok) {
        const error = new Error(result?.error?.message || `Arcade request failed (${response.status}).`);
        error.code = {
            401: "functions/unauthenticated",
            403: "functions/permission-denied",
            404: "functions/not-found",
            409: "functions/already-exists",
            429: "functions/resource-exhausted"
        }[response.status] || "functions/internal";
        throw error;
    }
    return { data: result.data };
}
let currentUser = null;
let selectedGame = null;
let unsubscribeComments = null;
let unsubscribeScores = null;
let unsubscribeMatch = null;
let unsubscribeQueue = null;
let currentQueueId = null;
let currentMatchId = null;
let activeMatch = null;
let movePending = false;
let matchExpiryTimer = null;
let matchCountdownTimer = null;
let arcadeLeaderboardRequest = 0;

function showMessage(id, text, error = false) {
    const element = document.getElementById(id);
    element.textContent = text;
    element.classList.toggle("is-error", error);
}

function createElement(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined) element.textContent = text;
    return element;
}

function activateTab(tabName) {
    for (const tab of tabs) {
        const active = tab.dataset.tab === tabName;
        tab.classList.toggle("is-active", active);
        tab.setAttribute("aria-selected", String(active));
    }
    document.querySelectorAll("[data-panel]").forEach((panel) => {
        panel.hidden = panel.dataset.panel !== tabName;
    });
    if (tabName === "ranked") loadLeaderboard();
    if (tabName === "ranked") loadCommunityLeaderboards();
    if (tabName === "leaderboard") loadArcadeLeaderboard();
    if (tabName === "moderation") document.getElementById("moderation-message").textContent = "Moderator permissions are checked securely on the server.";
}

tabs.forEach((tab) => tab.addEventListener("click", () => activateTab(tab.dataset.tab)));

async function loadSchedule() {
    const cards = document.getElementById("schedule-cards");
    try {
        const { data } = await call("getArcadeSchedule");
        cards.replaceChildren();
        const schedules = [
            { label: "DAILY GAME", title: "Today's challenge", item: data.daily, description: `New challenge · ${data.daily.date}` },
            { label: "WEEKLY GAME", title: "Weekly challenge", item: data.weekly, description: "A fresh game to master every week." },
            { label: "LIVE EVENT", title: data.event.title, item: data.event, description: "A rotating arcade spotlight." }
        ];
        for (const schedule of schedules) {
            const card = createElement("article", `spotlight-card spotlight-${schedule.label.split(" ")[0].toLowerCase()}`);
            card.append(createElement("span", "tile-number", schedule.label));
            card.append(createElement("h3", "", schedule.title));
            card.append(createElement("p", "", `${gameTitle(schedule.item.gameId)} · ${schedule.description}`));
            const link = createElement("a", "button button-primary", "Play challenge →");
            link.href = `game.html?game=${encodeURIComponent(schedule.item.gameId)}`;
            card.append(link);
            cards.append(card);
        }
    } catch (error) {
        cards.replaceChildren(createElement("p", "hub-empty", `Could not load challenges: ${error.message}`));
    }
}

function gameTitle(gameId) {
    return { catch: "Star Catcher", dodge: "Meteor Dash", hop: "Planet Hopper", dash: "Sky Dash" }[gameId] || "Arcade game";
}

function formatElapsed(seconds) {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return minutes ? `${minutes}m ${remainingSeconds}s` : `${remainingSeconds}s`;
}

async function loadArcadeLeaderboard() {
    const list = document.getElementById("arcade-leaderboard-list");
    const gameId = document.getElementById("arcade-leaderboard-game").value;
    const requestId = ++arcadeLeaderboardRequest;
    list.replaceChildren(createElement("p", "hub-empty", "Loading top scores..."));
    document.getElementById("arcade-leaderboard-updated").textContent = "All time";
    showMessage("arcade-leaderboard-message", "");
    try {
        const { data } = await call("getArcadeLeaderboard", { gameId });
        if (requestId !== arcadeLeaderboardRequest) return;
        list.replaceChildren();
        if (!data.entries.length) {
            list.append(createElement("p", "hub-empty", `No ${gameTitle(gameId)} scores have been submitted yet. Play a solo run to claim the first spot!`));
            return;
        }
        data.entries.forEach((entry, index) => {
            const row = createElement("div", "leaderboard-row arcade-leaderboard-row");
            row.append(createElement("span", "leaderboard-rank", `#${index + 1}`));
            row.append(createElement("span", "leaderboard-name", entry.displayName || "Player"));
            const score = createElement("strong", "leaderboard-score", String(entry.score));
            score.title = `Elapsed: ${formatElapsed(entry.elapsedSeconds)}`;
            row.append(score);
            row.append(createElement("span", "leaderboard-time", formatElapsed(entry.elapsedSeconds)));
            list.append(row);
        });
        document.getElementById("arcade-leaderboard-updated").textContent = `${data.entries.length} best runs · all time`;
    } catch (error) {
        if (requestId !== arcadeLeaderboardRequest) return;
        list.replaceChildren(createElement("p", "hub-empty", "Leaderboard standings are unavailable."));
        showMessage("arcade-leaderboard-message", `Could not load scores: ${error.message}`, true);
    }
}

document.getElementById("arcade-leaderboard-game").addEventListener("change", loadArcadeLeaderboard);

function leaderboardBoardId() {
    const game = document.getElementById("leaderboard-game").value;
    const mode = document.getElementById("leaderboard-mode").value;
    const day = new Date().toISOString().slice(0, 10);
    return `${game}_${mode}_${day}`;
}

function loadLeaderboard() {
    if (unsubscribeScores) unsubscribeScores();
    const list = document.getElementById("leaderboard-list");
    const boardId = leaderboardBoardId();
    document.getElementById("leaderboard-date").textContent = `UTC · ${new Date().toISOString().slice(0, 10)}`;
    showMessage("leaderboard-message", "");
    const scores = query(
        collection(db, "leaderboards", boardId, "scores"),
        orderBy("score", "desc"),
        limit(30)
    );
    unsubscribeScores = onSnapshot(scores, (snapshot) => {
        list.replaceChildren();
        if (snapshot.empty) {
            list.append(createElement("p", "hub-empty", "No scores yet today. Join an online match to set the first record!"));
            return;
        }
        snapshot.docs.forEach((entry, index) => {
            const row = createElement("div", "leaderboard-row");
            row.append(createElement("span", "leaderboard-rank", `#${index + 1}`));
            row.append(createElement("span", "leaderboard-name", entry.data().displayName || "Player"));
            row.append(createElement("strong", "leaderboard-score", String(entry.data().score)));
            list.append(row);
        });
    }, (error) => {
        showMessage("leaderboard-message", `Could not load scores: ${error.message}`, true);
    });
}

document.getElementById("leaderboard-game").addEventListener("change", loadLeaderboard);
document.getElementById("leaderboard-mode").addEventListener("change", loadLeaderboard);

async function loadCommunityLeaderboards() {
    const creatorList = document.getElementById("creator-leaderboard-list");
    const globalList = document.getElementById("global-leaderboard-list");
    creatorList.replaceChildren(createElement("p", "hub-empty", "Loading creator standings..."));
    globalList.replaceChildren(createElement("p", "hub-empty", "Loading global standings..."));
    showMessage("global-leaderboard-message", "");
    try {
        const { data } = await call("getCommunityLeaderboards");
        const render = (list, entries, emptyMessage, suffix) => {
            list.replaceChildren();
            if (!entries.length) {
                list.append(createElement("p", "hub-empty", emptyMessage));
                return;
            }
            entries.forEach((entry, index) => {
                const row = createElement("div", "leaderboard-row");
                row.append(createElement("span", "leaderboard-rank", `#${index + 1}`));
                row.append(createElement("span", "leaderboard-name", entry.displayName || "Player"));
                row.append(createElement("strong", "leaderboard-score", `${entry.value} ${suffix}`));
                list.append(row);
            });
        };
        render(creatorList, data.creators || [], "No player levels have been published yet.", "levels");
        render(globalList, data.global || [], "No ranked points have been earned yet.", "points");
    } catch (error) {
        creatorList.replaceChildren(createElement("p", "hub-empty", "Creator standings are unavailable."));
        globalList.replaceChildren(createElement("p", "hub-empty", "Global standings are unavailable."));
        showMessage("global-leaderboard-message", `Could not load global standings: ${error.message}`, true);
    }
}

document.getElementById("game-search-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const results = document.getElementById("community-games");
    const queryText = document.getElementById("game-search").value.trim();
    results.replaceChildren();
    document.getElementById("game-comments").hidden = true;
    if (!queryText) return;
    showMessage("search-message", "Searching published games...");
    try {
        const { data } = await call("searchGames", { query: queryText });
        showMessage("search-message", data.games.length ? `${data.games.length} game${data.games.length === 1 ? "" : "s"} found.` : "No published games matched that title or ID.");
        for (const game of data.games) renderGame(game, results);
    } catch (error) {
        showMessage("search-message", `Search failed: ${error.message}`, true);
    }
});

function renderGame(game, container) {
    const card = createElement("article", "community-game-card");
    const header = createElement("div", "community-game-heading");
    const title = createElement("div");
    const levelName = game.levelName || game.title || "Untitled level";
    title.append(createElement("span", "tile-number", `${gameTitle(game.config?.gameType)} · ${game.config?.difficulty || "normal"}`));
    title.append(createElement("h3", "", levelName));
    header.append(title);
    header.append(createElement("span", "creator-name", `by ${game.ownerName || "Player"}`));
    card.append(header);
    card.append(createElement("p", "community-game-description", game.description));
    card.append(createElement("code", "game-share-id", `Level ID: ${game.levelId ?? game.id}`));
    const actions = createElement("div", "community-game-actions");
    const playLink = createElement("a", "button button-primary", "Play mode →");
    playLink.href = `game.html?game=${encodeURIComponent(game.config.gameType)}&custom=${encodeURIComponent(game.id)}`;
    const commentsButton = createElement("button", "button button-quiet", "Comments");
    commentsButton.type = "button";
    commentsButton.addEventListener("click", () => showComments(game));
    const reportButton = createElement("button", "report-button", "Report game");
    reportButton.type = "button";
    reportButton.addEventListener("click", () => report("game", game.id, null));
    actions.append(playLink, commentsButton, reportButton);
    card.append(actions);
    container.append(card);
}

function showComments(game) {
    selectedGame = game;
    const panel = document.getElementById("game-comments");
    panel.hidden = false;
    document.getElementById("comments-title").textContent = `${game.title} · comments`;
    document.getElementById("comment-text").value = "";
    document.getElementById("comment-count").textContent = "0 / 300";
    document.getElementById("comments-list").replaceChildren(createElement("p", "hub-empty", "Loading comments..."));
    if (unsubscribeComments) unsubscribeComments();
    const comments = query(
        collection(db, "games", game.id, "comments"),
        where("status", "==", "visible"),
        orderBy("createdAt", "desc"),
        limit(30)
    );
    unsubscribeComments = onSnapshot(comments, (snapshot) => {
        const list = document.getElementById("comments-list");
        list.replaceChildren();
        if (snapshot.empty) {
            list.append(createElement("p", "hub-empty", "No comments yet. Be the first to leave a kind note."));
            return;
        }
        for (const comment of snapshot.docs) {
            const data = comment.data();
            const row = createElement("article", "comment-card");
            const header = createElement("div", "comment-header");
            header.append(createElement("strong", "", data.displayName || "Player"));
            const date = data.createdAt?.toDate ? data.createdAt.toDate().toLocaleDateString() : "Just now";
            header.append(createElement("span", "", date));
            row.append(header, createElement("p", "comment-text-content", data.text));
            const flag = createElement("button", "report-button", "Report");
            flag.type = "button";
            flag.addEventListener("click", () => report("comment", comment.id, game.id));
            row.append(flag);
            list.append(row);
        }
    }, (error) => {
        document.getElementById("comments-list").replaceChildren(createElement("p", "hub-empty", `Could not load comments: ${error.message}`));
    });
    panel.scrollIntoView({ behavior: "smooth", block: "start" });
}

document.getElementById("comment-text").addEventListener("input", (event) => {
    document.getElementById("comment-count").textContent = `${event.target.value.length} / 300`;
});

document.getElementById("comment-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    if (!selectedGame) return;
    const text = document.getElementById("comment-text").value.trim();
    try {
        const { data } = await call("addComment", { gameId: selectedGame.id, text });
        document.getElementById("comment-text").value = "";
        document.getElementById("comment-count").textContent = "0 / 300";
        showMessage("comment-message", data.status === "pending" ? "Your comment includes a link and is waiting for moderator review." : "Your comment was posted.");
    } catch (error) {
        showMessage("comment-message", `Could not post comment: ${error.message}`, true);
    }
});

async function report(type, contentId, gameId) {
    const reason = window.prompt("Briefly tell the moderators what's wrong. Please don't include private information.");
    if (!reason?.trim()) return;
    try {
        await call("reportContent", { type, contentId, gameId, reason: reason.trim() });
        showMessage(type === "comment" ? "comment-message" : "search-message", "Thanks. Your report was sent to the moderation queue.");
    } catch (error) {
        showMessage(type === "comment" ? "comment-message" : "search-message", `Could not submit report: ${error.message}`, true);
    }
}

function buildLevelPattern() {
    return Array.from(document.querySelectorAll(".level-cell")).map((cell) => cell.dataset.state || "empty");
}

function resetLevelPattern() {
    document.querySelectorAll(".level-cell").forEach((cell) => {
        cell.dataset.state = "empty";
        cell.classList.remove("is-spike");
        cell.classList.add("is-empty");
        cell.setAttribute("aria-label", "Empty step");
    });
}

document.querySelectorAll(".level-cell").forEach((cell) => {
    cell.addEventListener("click", () => {
        const nextState = cell.dataset.state === "spike" ? "empty" : "spike";
        cell.dataset.state = nextState;
        cell.classList.toggle("is-spike", nextState === "spike");
        cell.classList.toggle("is-empty", nextState === "empty");
        cell.setAttribute("aria-label", nextState === "spike" ? "Spike step" : "Empty step");
    });
});

document.getElementById("level-clear").addEventListener("click", resetLevelPattern);
document.getElementById("level-fill-spikes").addEventListener("click", () => {
    const cells = document.querySelectorAll(".level-cell");
    const filled = Array.from(cells).map((cell, column) => (column % 2 === 0 || column === cells.length - 1 ? "spike" : "empty"));
    cells.forEach((cell, index) => {
        const state = filled[index];
        cell.dataset.state = state;
        cell.classList.toggle("is-spike", state === "spike");
        cell.classList.toggle("is-empty", state === "empty");
        cell.setAttribute("aria-label", state === "spike" ? "Spike step" : "Empty step");
    });
});

document.getElementById("create-game-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const form = event.currentTarget;
    const submit = form.querySelector("button[type=submit]");
    const levelNameInput = form.querySelector('[name="levelName"]');
    const levelIdInput = form.querySelector('[name="levelId"]');
    const descriptionInput = form.querySelector('[name="description"]');
    const gameTypeInput = form.querySelector('[name="gameType"]');
    const difficultyInput = form.querySelector('[name="difficulty"]');
    const accentInput = form.querySelector('[name="accent"]');

    if (!levelNameInput || !levelIdInput || !descriptionInput || !gameTypeInput || !difficultyInput || !accentInput) {
        showMessage("create-message", "The level editor is missing form fields. Refresh the page and try again.", true);
        return;
    }

    const levelName = levelNameInput.value.trim();
    const levelId = levelIdInput.value.trim();
    const pattern = buildLevelPattern();
    const isNumericId = /^\d+$/.test(levelId);
    if (!isNumericId) {
        showMessage("create-message", "Level ID must contain only numbers.", true);
        return;
    }
    submit.disabled = true;
    showMessage("create-message", "Publishing your level...");
    try {
        const { data } = await call("publishGame", {
            levelName,
            levelId,
            title: levelName,
            description: descriptionInput.value.trim(),
            config: {
                gameType: gameTypeInput.value,
                difficulty: difficultyInput.value,
                accent: accentInput.value,
                pattern
            }
        });
        form.reset();
        resetLevelPattern();
        showMessage("create-message", `Level published! Level ID: ${levelId} · Share ID: ${data.id}`);
    } catch (error) {
        showMessage("create-message", `Could not publish level: ${error.message}`, true);
    } finally {
        submit.disabled = false;
    }
});

document.getElementById("find-match").addEventListener("click", async (event) => {
    const button = event.currentTarget;
    button.disabled = true;
    showMessage("match-message", "Looking for another player...");
    try {
        const { data } = await call("joinMatchmaking", {
            gameId: document.getElementById("match-game").value,
            mode: document.getElementById("match-mode").value
        });
        currentQueueId = data.queueId;
        document.getElementById("live-match").hidden = false;
        if (data.matchId) {
            showMessage("match-message", "Opponent found! Match is live.");
            watchMatch(data.matchId);
        } else {
            document.getElementById("match-status").textContent = "Waiting for another player...";
            showMessage("match-message", "You are in the queue. Leave this page open while we find an opponent.");
            watchQueue(data.queueId);
        }
    } catch (error) {
        showMessage("match-message", `Could not join matchmaking: ${error.message}`, true);
        button.disabled = false;
    }
});

function watchQueue(queueId) {
    if (unsubscribeQueue) unsubscribeQueue();
    unsubscribeQueue = onSnapshot(doc(db, "matchmaking", queueId), (snapshot) => {
        if (!snapshot.exists()) {
            showMessage("match-message", "Your matchmaking request is no longer available.", true);
            return;
        }
        const queue = snapshot.data();
        if (queue.status === "matched" && queue.matchId) {
            unsubscribeQueue();
            unsubscribeQueue = null;
            showMessage("match-message", "Opponent found! Match is live.");
            watchMatch(queue.matchId);
        } else if (queue.status !== "waiting") {
            unsubscribeQueue();
            unsubscribeQueue = null;
            document.getElementById("find-match").disabled = false;
            showMessage("match-message", `Match queue status: ${queue.status}.`, true);
        }
    }, (error) => {
        showMessage("match-message", `Matchmaking connection failed: ${error.message}`, true);
    });
}

function renderMatch(match) {
    const board = document.getElementById("match-board");
    board.replaceChildren();
    const myPlayer = match.players[currentUser.uid];
    const otherUid = match.playerIds.find((uid) => uid !== currentUser.uid);
    const otherPlayer = otherUid ? match.players[otherUid] : null;
    if (myPlayer) document.getElementById("my-live-score").textContent = String(myPlayer.score);
    if (otherPlayer) document.getElementById("opponent-live-score").textContent = String(otherPlayer.score);
    for (let y = 0; y < 7; y += 1) {
        for (let x = 0; x < 7; x += 1) {
            const cell = createElement("div", "match-cell");
            if (match.target?.x === x && match.target?.y === y) {
                cell.classList.add("match-target");
                cell.textContent = "⭐";
                cell.setAttribute("aria-label", "Star");
            } else if (myPlayer?.x === x && myPlayer?.y === y) {
                cell.classList.add("match-self");
                cell.textContent = "🚀";
                cell.setAttribute("aria-label", "You");
            } else if (otherPlayer?.x === x && otherPlayer?.y === y) {
                cell.classList.add("match-opponent");
                cell.textContent = "🛸";
                cell.setAttribute("aria-label", "Opponent");
            }
            board.append(cell);
        }
    }
    if (match.status === "complete") {
        const result = match.winnerId
            ? (match.winnerId === currentUser.uid ? "Match complete — you win, your opponent left." : "Match complete — you left the match.")
            : myPlayer?.score === otherPlayer?.score
                ? "Match complete — it's a tie!"
                : myPlayer?.score > otherPlayer?.score ? "Match complete — you win!" : "Match complete — your opponent wins.";
        document.getElementById("match-status").textContent = result;
        showMessage("match-message", result);
    } else {
        const remaining = Math.max(0, Math.ceil((match.endsAt.toMillis() - Date.now()) / 1000));
        document.getElementById("match-status").textContent = `Live match · ${remaining}s left`;
    }
}

function watchMatch(matchId) {
    currentMatchId = matchId;
    if (unsubscribeMatch) unsubscribeMatch();
    unsubscribeMatch = onSnapshot(doc(db, "matches", matchId), (snapshot) => {
        if (!snapshot.exists()) {
            showMessage("match-message", "This match is no longer available.", true);
            return;
        }
        activeMatch = snapshot.data();
        renderMatch(activeMatch);
        if (activeMatch.status === "playing") {
            if (!matchExpiryTimer) {
                const delay = Math.max(0, activeMatch.endsAt.toMillis() - Date.now() + 250);
                matchExpiryTimer = window.setTimeout(() => {
                    call("completeExpiredMatch", { matchId }).catch((error) => {
                        showMessage("match-message", `Could not update match status: ${error.message}`, true);
                    });
                }, delay);
                matchCountdownTimer = window.setInterval(() => {
                    if (activeMatch?.status !== "playing") return;
                    const remaining = Math.max(0, Math.ceil((activeMatch.endsAt.toMillis() - Date.now()) / 1000));
                    document.getElementById("match-status").textContent = `Live match · ${remaining}s left`;
                }, 1000);
            }
        } else {
            if (matchExpiryTimer) clearTimeout(matchExpiryTimer);
            if (matchCountdownTimer) clearInterval(matchCountdownTimer);
            matchExpiryTimer = null;
            matchCountdownTimer = null;
        }
    }, (error) => {
        showMessage("match-message", `Live match connection failed: ${error.message}`, true);
    });
}

async function submitMove(direction) {
    if (!currentMatchId || !activeMatch || activeMatch.status !== "playing" || movePending) return;
    movePending = true;
    try {
        await call("submitMatchMove", { matchId: currentMatchId, direction });
    } catch (error) {
        if (error.code === "functions/resource-exhausted") {
            showMessage("match-message", "Slow down just a little—moves have a short cooldown.");
        } else {
            showMessage("match-message", `Move rejected: ${error.message}`, true);
        }
    } finally {
        movePending = false;
    }
}

document.querySelectorAll("[data-online-move]").forEach((button) => {
    button.addEventListener("click", () => submitMove(button.dataset.onlineMove));
});
document.addEventListener("keydown", (event) => {
    if (document.querySelector('[data-panel="online"]:not([hidden])') === null) return;
    const direction = { ArrowUp: "up", w: "up", W: "up", ArrowDown: "down", s: "down", S: "down", ArrowLeft: "left", a: "left", A: "left", ArrowRight: "right", d: "right", D: "right" }[event.key];
    if (direction && activeMatch?.status === "playing") {
        event.preventDefault();
        submitMove(direction);
    }
});

document.getElementById("leave-match").addEventListener("click", async () => {
    try {
        if (unsubscribeQueue) unsubscribeQueue();
        unsubscribeQueue = null;
        if (currentQueueId) await call("leaveMatchmaking", { queueId: currentQueueId });
        if (currentMatchId) await call("leaveMatch", { matchId: currentMatchId });
        if (matchExpiryTimer) clearTimeout(matchExpiryTimer);
        if (matchCountdownTimer) clearInterval(matchCountdownTimer);
        matchExpiryTimer = null;
        matchCountdownTimer = null;
        if (unsubscribeMatch) unsubscribeMatch();
        unsubscribeMatch = null;
        activeMatch = null;
        currentMatchId = null;
        currentQueueId = null;
        document.getElementById("live-match").hidden = true;
        document.getElementById("find-match").disabled = false;
        showMessage("match-message", "You left the match queue.");
    } catch (error) {
        showMessage("match-message", `Could not leave: ${error.message}`, true);
    }
});

document.getElementById("load-reports").addEventListener("click", async () => {
    const list = document.getElementById("moderation-reports");
    list.replaceChildren();
    showMessage("moderation-message", "Loading reports...");
    try {
        const { data } = await call("moderationQueue");
        showMessage("moderation-message", `${data.reports.length} open report${data.reports.length === 1 ? "" : "s"}.`);
        if (!data.reports.length) list.append(createElement("p", "hub-empty", "The moderation queue is clear."));
        for (const report of data.reports) renderReport(report, list);
    } catch (error) {
        showMessage("moderation-message", `Could not load reports: ${error.message}`, true);
    }
});

function renderReport(report, list) {
    const card = createElement("article", "moderation-card");
    card.append(createElement("span", "tile-number", `${report.type.toUpperCase()} · ${report.contentId}`));
    card.append(createElement("p", "", report.reason));
    const actions = createElement("div", "community-game-actions");
    const moderationActions = report.type === "comment"
        ? [["approve", "Approve"], ["remove", "Remove"]]
        : report.type === "game" ? [["restore", "Restore"], ["remove", "Remove"]]
            : [["restore", "Restore user"], ["suspend", "Suspend user"]];
    for (const [action, label] of moderationActions) {
        const button = createElement("button", "button button-quiet", label);
        button.type = "button";
        button.addEventListener("click", async () => {
            button.disabled = true;
            try {
                const moderationRequest = {
                    type: report.type,
                    contentId: report.contentId,
                    gameId: report.gameId,
                    action
                };
                if (report.id && !report.isPending) moderationRequest.reportId = report.id;
                await call("moderateContent", moderationRequest);
                card.remove();
                showMessage("moderation-message", "Report reviewed.");
            } catch (error) {
                button.disabled = false;
                showMessage("moderation-message", `Moderation action failed: ${error.message}`, true);
            }
        });
        actions.append(button);
    }
    card.append(actions);
    list.append(card);
}

document.getElementById("community-sign-out").addEventListener("click", async () => {
    try {
        await signOut(auth);
    } catch (error) {
        showMessage("community-loading", `Could not sign out: ${error.message}`, true);
    }
});

const deleteAccountDialog = document.getElementById("delete-account-dialog");
const deleteAccountForm = document.getElementById("delete-account-form");
document.getElementById("settings-player-name").textContent = "Loading account...";
document.getElementById("open-delete-account").addEventListener("click", () => {
    deleteAccountForm.reset();
    showMessage("delete-dialog-message", "");
    deleteAccountDialog.showModal();
});
document.getElementById("cancel-delete-account").addEventListener("click", () => deleteAccountDialog.close());
deleteAccountForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    const submit = document.getElementById("confirm-delete-account");
    if (deleteAccountForm.elements.confirmation.value.trim() !== "DELETE") {
        showMessage("delete-dialog-message", "Type DELETE exactly to confirm account deletion.", true);
        return;
    }
    if (!currentUser?.email) {
        showMessage("delete-dialog-message", "This account cannot be reauthenticated with an email password. Contact support.", true);
        return;
    }
    submit.disabled = true;
    showMessage("delete-dialog-message", "Reauthenticating and deleting your account...");
    try {
        const credential = EmailAuthProvider.credential(currentUser.email, deleteAccountForm.elements.password.value);
        await reauthenticateWithCredential(currentUser, credential);
        await call("deleteAccount");
        await signOut(auth);
        window.location.replace("index.html");
    } catch (error) {
        showMessage("delete-dialog-message", `Could not delete the account: ${error.message}`, true);
    } finally {
        submit.disabled = false;
    }
});

onAuthStateChanged(auth, (user) => {
    window.__starboundAuthResolved = true;
    if (!user) {
        window.location.replace(`index.html${window.location.search}`);
        return;
    }
    currentUser = user;
    document.getElementById("community-player").textContent = user.displayName || user.email || "Player";
    document.getElementById("settings-player-name").textContent = user.email || user.displayName || "Signed-in player";
    loading.hidden = true;
    app.hidden = false;
    syncPlayerLink(user, user.displayName || user.email?.split("@")[0] || "Player")
        .then(loadSchedule)
        .catch((error) => showMessage("schedule-message", `The shared arcade backend is not ready. Enable Firestore and deploy the Cloud Functions using PLATFORM_SETUP.md. Details: ${error.message}`, true));
}, (error) => {
    window.__starboundAuthResolved = true;
    loading.textContent = `Could not verify your sign-in: ${error.message}`;
});

window.addEventListener("pagehide", () => {
    if (unsubscribeComments) unsubscribeComments();
    if (unsubscribeScores) unsubscribeScores();
    if (unsubscribeMatch) unsubscribeMatch();
    if (unsubscribeQueue) unsubscribeQueue();
    if (matchExpiryTimer) clearTimeout(matchExpiryTimer);
    if (matchCountdownTimer) clearInterval(matchCountdownTimer);
}, { once: true });
