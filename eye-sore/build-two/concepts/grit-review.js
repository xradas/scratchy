"use strict";

const status = document.getElementById("view-status");
document.getElementById("target-view").addEventListener("change", (event) => {
  const pixelPreview = event.target.value === "scene_pixel_preview";
  const source = `visual-v2/corrupted-biotech/${pixelPreview ? "scene_pixel_preview" : "scene"}.png`;
  const label = pixelPreview ? "Approved top thumbnail / pixel preview" : "Original approved concept scene";
  const image = document.getElementById("target-image");
  image.src = source;
  image.alt = `${label}: Pale Ward concept artwork`;
  const link = document.getElementById("target-link");
  link.href = source;
  link.setAttribute("aria-label", `Open ${label.toLowerCase()} original PNG`);
  document.getElementById("target-caption").textContent = `${label}. Concept artwork, not a game capture.`;
  status.textContent = `Target view changed to ${label.toLowerCase()}.`;
});

document.getElementById("current-view").addEventListener("change", (event) => {
  const option = event.target.selectedOptions[0];
  const source = `grit-review-assets/${option.value}.png`;
  const location = option.textContent.toLowerCase();
  const image = document.getElementById("current-image");
  image.src = source;
  image.alt = `Actual current game native screenshot: ${location}`;
  const link = document.getElementById("current-link");
  link.href = source;
  link.setAttribute("aria-label", `Open actual current game ${location} original PNG`);
  document.getElementById("current-caption").textContent = `Actual current game: ${location}. Native capture copied byte for byte.`;
  status.textContent = `Actual current game view changed to ${location}.`;
});
