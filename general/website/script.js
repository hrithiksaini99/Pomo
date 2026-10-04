"use strict";

// Optional motion never hides content when JavaScript or observation is unavailable.
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
if (!reduceMotion && "IntersectionObserver" in window) {
  document.documentElement.classList.add("motion-ready");
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.08 });
  document.querySelectorAll(".reveal").forEach(node => observer.observe(node));
}

const tagline = document.querySelector("[data-word-reveal]");
if (tagline) {
  const lines = tagline.innerHTML.split(/<br\s*\/?\s*>/i);
  tagline.replaceChildren();
  let index = 0;
  lines.forEach((line, lineIndex) => {
    if (lineIndex) tagline.append(document.createElement("br"));
    line.split(/\s+/).filter(Boolean).forEach(word => {
      const span = document.createElement("span");
      span.className = "tagline-word";
      span.textContent = word;
      span.dataset.order = String(index++);
      tagline.append(span, document.createTextNode(" "));
    });
  });
  if (!reduceMotion && "IntersectionObserver" in window) {
    const wordObserver = new IntersectionObserver(entries => {
      entries.filter(entry => entry.isIntersecting).forEach(entry => {
        window.setTimeout(() => entry.target.classList.add("is-active"), Number(entry.target.dataset.order) * 90);
        wordObserver.unobserve(entry.target);
      });
    }, { rootMargin: "0px 0px -18% 0px", threshold: 1 });
    tagline.querySelectorAll(".tagline-word").forEach(word => wordObserver.observe(word));
  } else tagline.querySelectorAll(".tagline-word").forEach(word => word.classList.add("is-active"));
}

const menuToggle = document.querySelector(".menu-toggle");
const mobileNavigation = document.querySelector(".mobile-overlay");
let navigationOrigin;
function setNavigation(open) {
  if (!menuToggle || !mobileNavigation) return;
  if (open) navigationOrigin = document.activeElement;
  menuToggle.setAttribute("aria-expanded", String(open));
  menuToggle.setAttribute("aria-label", open ? "Close navigation" : "Open navigation");
  mobileNavigation.hidden = !open;
  document.body.style.overflow = open ? "hidden" : "";
  if (open) mobileNavigation.querySelector("a")?.focus();
  else navigationOrigin?.focus();
}
menuToggle?.addEventListener("click", () => setNavigation(menuToggle.getAttribute("aria-expanded") !== "true"));
mobileNavigation?.querySelectorAll("a").forEach(link => link.addEventListener("click", () => setNavigation(false)));
document.addEventListener("keydown", event => {
  if (mobileNavigation?.hidden === false) {
    if (event.key === "Escape") { setNavigation(false); return; }
    if (event.key === "Tab") {
      const focusable = [menuToggle, ...mobileNavigation.querySelectorAll("a")];
      const current = focusable.indexOf(document.activeElement);
      if ((event.shiftKey && current === 0) || (!event.shiftKey && current === focusable.length - 1)) {
        event.preventDefault();
        focusable[event.shiftKey ? focusable.length - 1 : 0].focus();
      }
    }
  }
});
window.matchMedia("(min-width: 761px)").addEventListener("change", event => { if (event.matches) setNavigation(false); });

// This is a browser demonstration of the native app, not a saved focus session.
const preview = document.getElementById("preview");
if (preview) {
  let preset = { minutes: 25, focus: true };
  let remaining = 25 * 60;
  let timerStartedAt = Date.now();
  let timerRunning = true;
  let completedSessions = 0;
  let stopwatchAccumulated = 0;
  let stopwatchStartedAt = null;
  const status = document.getElementById("demo-status");
  const menu = document.getElementById("demo-menu");
  const countdownLabel = document.getElementById("demo-countdown");
  const pause = document.getElementById("demo-pause");
  const stopwatchToggle = document.getElementById("demo-toggle-stopwatch");
  const reset = document.getElementById("demo-reset-stopwatch");
  const notice = document.getElementById("demo-notice");
  const presetButtons = [...preview.querySelectorAll(".demo-preset")];

  function format(time, roundUp = false) {
    const seconds = Math.max(0, roundUp ? Math.ceil(time) : Math.floor(time));
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const parts = [String(minutes).padStart(2, "0"), String(seconds % 60).padStart(2, "0")];
    return hours ? `${hours}:${parts.join(":")}` : parts.join(":");
  }
  const timeLeft = () => preset ? Math.max(0, remaining - (timerRunning ? (Date.now() - timerStartedAt) / 1000 : 0)) : 0;
  const stopwatchTime = () => stopwatchAccumulated + (stopwatchStartedAt !== null ? (Date.now() - stopwatchStartedAt) / 1000 : 0);
  function render() {
    const left = timeLeft();
    if (preset && timerRunning && left <= 0) {
      if (preset.focus) completedSessions += 1;
      notice.textContent = preset.focus ? "Focus session done. Take a break." : "Break’s over. Back to it.";
      notice.hidden = false;
      preset = null;
      timerRunning = false;
      remaining = 0;
    }
    countdownLabel.textContent = preset ? format(left, true) : "";
    countdownLabel.hidden = !preset;
    status.classList.toggle("is-paused", Boolean(preset && !timerRunning));
    document.getElementById("timer-controls").hidden = !preset;
    pause.textContent = timerRunning ? "Pause Timer" : "Resume Timer";
    const elapsed = stopwatchTime();
    const stopwatchText = format(elapsed);
    document.getElementById("status-stopwatch").hidden = !(elapsed > 0 || stopwatchStartedAt !== null);
    document.getElementById("demo-stopwatch").textContent = stopwatchText;
    document.getElementById("menu-stopwatch").textContent = stopwatchText;
    stopwatchToggle.textContent = stopwatchStartedAt !== null ? "Pause Stopwatch" : (elapsed > 0 ? "Resume Stopwatch" : "Start Stopwatch");
    reset.hidden = !(elapsed > 0 || stopwatchStartedAt !== null);
    document.getElementById("demo-focus-count").textContent = `Pomo · ${completedSessions} focus sessions done`;
    presetButtons.forEach(button => {
      const selected = preset !== null && Number(button.dataset.minutes) === preset.minutes && (button.dataset.focus === "true") === preset.focus;
      button.setAttribute("aria-pressed", String(selected));
      button.querySelector(".preset-check").textContent = selected ? "✓" : "";
    });
  }
  presetButtons.forEach(button => button.addEventListener("click", () => {
    preset = { minutes: Number(button.dataset.minutes), focus: button.dataset.focus === "true" };
    remaining = preset.minutes * 60;
    timerStartedAt = Date.now();
    timerRunning = true;
    notice.hidden = true;
    render();
  }));
  pause.addEventListener("click", () => {
    if (!preset) return;
    remaining = timeLeft();
    timerStartedAt = Date.now();
    timerRunning = !timerRunning;
    render();
  });
  document.getElementById("demo-stop").addEventListener("click", () => {
    preset = null; timerRunning = false; remaining = 0; render();
  });
  stopwatchToggle.addEventListener("click", () => {
    stopwatchAccumulated = stopwatchTime();
    stopwatchStartedAt = stopwatchStartedAt !== null ? null : Date.now();
    render();
  });
  reset.addEventListener("click", () => { stopwatchAccumulated = 0; stopwatchStartedAt = null; render(); });
  status.addEventListener("click", () => {
    menu.hidden = !menu.hidden;
    status.setAttribute("aria-expanded", String(!menu.hidden));
  });
  render();
  const interval = window.setInterval(render, 250);
  window.addEventListener("pagehide", () => window.clearInterval(interval));
}

const copyButton = document.getElementById("copy-install");
copyButton?.addEventListener("click", async () => {
  const status = document.getElementById("copy-status");
  const command = document.getElementById("install-command").textContent;
  copyButton.disabled = true;
  try {
    if (!navigator.clipboard?.writeText) throw new Error("Clipboard unavailable");
    await navigator.clipboard.writeText(command);
    status.textContent = "Copied. Paste the commands into Terminal.";
  } catch {
    status.textContent = "Copy isn’t available here. Select the commands above to copy them.";
  } finally { copyButton.disabled = false; }
});
