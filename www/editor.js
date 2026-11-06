import * as THREE from "https://cdn.jsdelivr.net/npm/three@0.180.0/build/three.module.js";

const STORAGE_KEY = "starbound-dash-editor";
const STEP_TOTAL = 24;
const DEFAULTS = {
    version: 1,
    levelName: "Neon Run",
    look: {
        background: "#11102c",
        ground: "#211d42",
        player: "#d8ccff",
        obstacle: "#ff8d7a"
    },
    pattern: Array(STEP_TOTAL).fill("empty")
};
function createDefaultLevel() {
    return {
        ...DEFAULTS,
        look: { ...DEFAULTS.look },
        pattern: [...DEFAULTS.pattern]
    };
}
const preview = document.getElementById("level-preview");
const timeline = document.getElementById("level-timeline");
const status = document.getElementById("editor-status");
const levelNameInput = document.getElementById("level-name");
const colorInputs = {
    background: document.getElementById("background-color"),
    ground: document.getElementById("ground-color"),
    player: document.getElementById("player-color"),
    obstacle: document.getElementById("obstacle-color")
};
let level = createDefaultLevel();
let activeTool = "spike";
let renderer;
let camera;
let scene;
let floor;
let grid;
let runner;
let hazards = [];

function initializePreview() {
    renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.domElement.setAttribute("aria-hidden", "true");
    preview.prepend(renderer.domElement);

    scene = new THREE.Scene();
    scene.background = new THREE.Color(level.look.background);
    scene.fog = new THREE.Fog(level.look.background, 18, 45);
    camera = new THREE.PerspectiveCamera(44, 1, 0.1, 100);
    camera.position.set(0, 7.5, 13);
    camera.lookAt(0, 0, -7);
    scene.add(new THREE.HemisphereLight(0xd8d0ff, 0x282044, 2.2));

    const keyLight = new THREE.DirectionalLight(0xffffff, 3);
    keyLight.position.set(-5, 9, 8);
    scene.add(keyLight);

    floor = new THREE.Mesh(
        new THREE.PlaneGeometry(17, 44),
        new THREE.MeshStandardMaterial({ color: level.look.ground, roughness: 0.82, metalness: 0.08 })
    );
    floor.rotation.x = -Math.PI / 2;
    floor.position.set(0, -0.55, -7);
    scene.add(floor);

    grid = new THREE.GridHelper(17, 17, level.look.player, 0x493b70);
    grid.position.set(0, -0.53, -7);
    scene.add(grid);

    const starPositions = [];
    for (let index = 0; index < 110; index += 1) {
        starPositions.push((Math.random() - 0.5) * 55, Math.random() * 18 + 1, (Math.random() - 0.5) * 50 - 8);
    }
    const starGeometry = new THREE.BufferGeometry();
    starGeometry.setAttribute("position", new THREE.Float32BufferAttribute(starPositions, 3));
    scene.add(new THREE.Points(
        starGeometry,
        new THREE.PointsMaterial({ color: 0xffffff, size: 0.11, transparent: true, opacity: 0.78 })
    ));

    runner = new THREE.Mesh(
        new THREE.BoxGeometry(0.9, 0.9, 0.9),
        new THREE.MeshStandardMaterial({
            color: level.look.player,
            emissive: level.look.player,
            emissiveIntensity: 0.42,
            metalness: 0.3,
            roughness: 0.3
        })
    );
    runner.position.set(0, 0.05, 3.2);
    scene.add(runner);
    resizePreview();
    renderPreview();
    renderer.setAnimationLoop(() => {
        if (!scene || !renderer) return;
        runner.rotation.y = Math.sin(performance.now() * 0.0007) * 0.12;
        renderer.render(scene, camera);
    });
    new ResizeObserver(resizePreview).observe(preview);
}

function resizePreview() {
    if (!renderer || !camera) return;
    const { width, height } = preview.getBoundingClientRect();
    if (!width || !height) return;
    renderer.setSize(width, height, false);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
}

function clearHazards() {
    for (const hazard of hazards) {
        scene.remove(hazard);
        hazard.traverse((part) => {
            part.geometry?.dispose();
            if (Array.isArray(part.material)) part.material.forEach((material) => material.dispose());
            else part.material?.dispose();
        });
    }
    hazards = [];
}

function createHazard(type, index) {
    const hazard = new THREE.Group();
    const material = new THREE.MeshStandardMaterial({
        color: level.look.obstacle,
        emissive: level.look.obstacle,
        emissiveIntensity: 0.22,
        metalness: 0.22,
        roughness: 0.38
    });
    const lanePositions = [-4.8, -2.4, 0, 2.4, 4.8];
    if (type === "block") {
        const block = new THREE.Mesh(new THREE.BoxGeometry(1.05, 1.25, 0.9), material);
        block.position.y = 0.08;
        hazard.add(block);
    } else {
        const base = new THREE.Mesh(new THREE.BoxGeometry(1.05, 0.72, 0.9), material);
        base.position.y = -0.15;
        hazard.add(base);
        const spike = new THREE.Mesh(new THREE.ConeGeometry(0.52, 1.1, 5), material);
        spike.position.y = 0.72;
        hazard.add(spike);
    }
    hazard.position.set(lanePositions[(index * 3) % lanePositions.length], -0.08, 1 - index * 0.92);
    scene.add(hazard);
    hazards.push(hazard);
}

function renderPreview() {
    if (!renderer || !scene) return;
    scene.background.set(level.look.background);
    scene.fog.color.set(level.look.background);
    floor.material.color.set(level.look.ground);
    runner.material.color.set(level.look.player);
    runner.material.emissive.set(level.look.player);
    for (const material of Array.isArray(grid.material) ? grid.material : [grid.material]) {
        material.color.set(level.look.player);
    }
    document.getElementById("preview-level-name").textContent = (level.levelName || "UNTITLED LEVEL").toUpperCase();
    clearHazards();
    level.pattern.forEach((state, index) => {
        if (state !== "empty") createHazard(state, index);
    });
    renderer.render(scene, camera);
}

function isColor(value) {
    return typeof value === "string" && /^#[0-9a-f]{6}$/i.test(value);
}

function setStatus(message, isError = false) {
    status.textContent = message;
    status.classList.toggle("is-error", isError);
}

function updateStepCount() {
    const count = level.pattern.filter((item) => item !== "empty").length;
    document.getElementById("step-count").textContent = `${count} / ${STEP_TOTAL}`;
}

function drawTimeline() {
    timeline.replaceChildren();
    level.pattern.forEach((state, index) => {
        const beat = document.createElement("button");
        beat.type = "button";
        beat.className = "timeline-beat";
        beat.dataset.state = state;
        beat.setAttribute("aria-label", `Beat ${index + 1}: ${state}`);
        beat.title = `Beat ${index + 1} · ${state}`;
        const number = document.createElement("span");
        number.textContent = String(index + 1).padStart(2, "0");
        beat.append(number);
        beat.addEventListener("click", () => {
            level.pattern[index] = activeTool === "empty"
                ? "empty"
                : level.pattern[index] === activeTool ? "empty" : activeTool;
            drawTimeline();
            renderPreview();
        });
        timeline.append(beat);
    });
    updateStepCount();
}

function syncForm() {
    levelNameInput.value = level.levelName;
    for (const [key, input] of Object.entries(colorInputs)) input.value = level.look[key];
    drawTimeline();
    renderPreview();
}

function loadSavedLevel() {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (!saved) return;
    const parsed = JSON.parse(saved);
    if (parsed?.version !== 1
        || !Array.isArray(parsed.pattern)
        || parsed.pattern.length !== STEP_TOTAL
        || !parsed.pattern.every((item) => ["empty", "spike", "block"].includes(item))
        || !parsed.look
        || !["background", "ground", "player", "obstacle"].every((key) => isColor(parsed.look[key]))
        || typeof parsed.levelName !== "string") {
        throw new Error("Saved editor data is invalid. Use Reset editor to start a fresh level.");
    }
    level = {
        version: 1,
        levelName: parsed.levelName.slice(0, 48) || DEFAULTS.levelName,
        look: { ...parsed.look },
        pattern: [...parsed.pattern]
    };
}

document.querySelectorAll("[data-tool]").forEach((button) => {
    button.addEventListener("click", () => {
        activeTool = button.dataset.tool;
        document.querySelectorAll("[data-tool]").forEach((tool) => {
            const isActive = tool === button;
            tool.classList.toggle("is-active", isActive);
            tool.setAttribute("aria-pressed", String(isActive));
        });
    });
});

levelNameInput.addEventListener("input", () => {
    level.levelName = levelNameInput.value.slice(0, 48);
    renderPreview();
});
for (const [key, input] of Object.entries(colorInputs)) {
    input.addEventListener("input", () => {
        level.look[key] = input.value;
        renderPreview();
    });
}
document.getElementById("clear-level").addEventListener("click", () => {
    level.pattern = Array(STEP_TOTAL).fill("empty");
    drawTimeline();
    renderPreview();
    setStatus("Pattern cleared. Save when you're ready.");
});
document.getElementById("reset-editor").addEventListener("click", () => {
    level = createDefaultLevel();
    activeTool = "spike";
    document.querySelector('[data-tool="spike"]').click();
    syncForm();
    setStatus("Editor reset. Save to replace your saved level.");
});
document.getElementById("save-level").addEventListener("click", () => {
    level.levelName = levelNameInput.value.trim().slice(0, 48) || "Untitled Level";
    try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(level));
        levelNameInput.value = level.levelName;
        renderPreview();
        setStatus("Level saved on this device.");
    } catch (error) {
        setStatus(`Could not save your level: ${error.message}`, true);
    }
});
function saveBeforeTest(event) {
    level.levelName = levelNameInput.value.trim().slice(0, 48) || "Untitled Level";
    try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(level));
    } catch (error) {
        event.preventDefault();
        setStatus(`Could not save your level: ${error.message}`, true);
    }
}
document.getElementById("test-level").addEventListener("click", saveBeforeTest);
document.getElementById("top-test-level").addEventListener("click", saveBeforeTest);
window.addEventListener("resize", renderPreview);
window.addEventListener("storage", (event) => {
    if (event.key !== STORAGE_KEY) return;
    try {
        level = createDefaultLevel();
        loadSavedLevel();
        syncForm();
        setStatus("Loaded the latest saved level.");
    } catch (error) {
        setStatus(`Could not load saved level: ${error.message}`, true);
    }
});

try {
    initializePreview();
} catch (error) {
    setStatus(`Could not start the 3D preview: ${error.message}`, true);
}
try {
    loadSavedLevel();
    syncForm();
} catch (error) {
    syncForm();
    setStatus(`Could not load saved level: ${error.message}`, true);
}
