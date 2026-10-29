const fullscreenButtons = document.querySelectorAll("[data-fullscreen-target]");
const fullscreenMessage = document.createElement("p");

fullscreenMessage.className = "fullscreen-message";
fullscreenMessage.setAttribute("role", "status");
fullscreenMessage.setAttribute("aria-live", "polite");
document.body.append(fullscreenMessage);

function getFullscreenTarget(button) {
    return button.dataset.fullscreenTarget === "game"
        ? document.getElementById("game-stage")
        : document.documentElement;
}

function updateFullscreenButtons() {
    fullscreenButtons.forEach((button) => {
        const target = getFullscreenTarget(button);
        const isFullscreen = target && document.fullscreenElement === target;
        const label = button.dataset.fullscreenTarget === "game" ? "game" : "website";
        button.textContent = isFullscreen ? `Exit ${label} fullscreen` : `Fullscreen ${label}`;
        button.setAttribute("aria-pressed", String(Boolean(isFullscreen)));
    });
}

fullscreenButtons.forEach((button) => {
    button.addEventListener("click", async () => {
        const target = getFullscreenTarget(button);
        if (!target || !document.fullscreenEnabled || typeof target.requestFullscreen !== "function") {
            fullscreenMessage.textContent = "Fullscreen is not supported by this browser or page.";
            return;
        }

        try {
            if (document.fullscreenElement === target) {
                await document.exitFullscreen();
            } else {
                await target.requestFullscreen();
            }
            fullscreenMessage.textContent = "";
            updateFullscreenButtons();
        } catch (error) {
            const reason = error instanceof Error ? error.message : String(error);
            fullscreenMessage.textContent = `Could not change fullscreen mode: ${reason}`;
        }
    });
});

document.addEventListener("fullscreenchange", updateFullscreenButtons);
document.addEventListener("fullscreenerror", () => {
    fullscreenMessage.textContent = "The browser could not change fullscreen mode.";
});
updateFullscreenButtons();
