# Compact HUD — second UI pass

Stacked on PR #86. Keep the F1 shortcut overlay responsive to viewport resizing; use smaller help typography under 1100px width or 720px height and adjust its horizontal safe margins. Toast width is capped to 80% of viewport. Hide the campus weather/status card outside F1 expanded help unless a timed campus-life message is active; the information remains available via the existing help toggle.

No new input bindings, persistence, multiplayer state or gameplay logic. This is a narrow HUD pass, not a full menu rewrite.

Validation pending: Godot headless import, smoke script, 960x540 / 1280x720 / 1920x1080 screenshots, English and Chinese help overflow, F1 toggling and notification timing. The smoke script checks source hooks, not rendering correctness.
