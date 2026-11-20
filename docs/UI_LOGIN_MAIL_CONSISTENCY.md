# Login and mailbox UI consistency

This UI-only change builds on the compact HUD and responsive session/coursework panel PRs. The login, local-profile and mailbox surfaces now use the same quiet off-white neutral material, reduced corner radii and consistent heading scale.

No authentication behavior, local account persistence, mail storage, network API, shortcuts or gameplay semantics are changed. No third-party font files are bundled.

Required QA before merging: Godot parse and headless test, screenshots at 960x540/1280x720/1920x1080, keyboard focus and tab traversal, Chinese/English text length, login error visibility, mailbox list overflow and high-DPI behavior. This change does not yet implement adaptive mailbox columns.
