# M18 — One display language per login session

**Scope:** original offline game UI and authored dialogue, using the already-installed GameLanguage service. No new network calls, purchased translations, or migration of XP/mission saves.

## Player behavior

- The **login screen** has one language selector. Players choose **中文** or **English**, then sign in/register. Only the selected language appears on that screen.
- The login choice is saved locally with the active player profile as `ui_locale`, as well as the existing device preference. The **chosen value for this login** wins: a previous player's locale is never silently forced onto a new player.
- Once signed in, the language is locked until logout. The old game-profile language button is removed, and **F10 changes language only on the login screen**, not during play. Logout restores an editable selector. No level or mail data are reset.
- UI changes are propagated centrally through `GameLanguage.language_changed`; screens generated after login use the current locale too. No bilingual strings with slashes should appear in a single language's user-facing narrative.
- Proper names (such as NUS, ERC, SRC, NPC names), keyboard keys, file extensions and technical terms are not language switching errors.

## Covered content

- Login, registration, tutorial access, sound controls, profile HUD and game-only mailbox chrome.
- The four-beat, 12-second intro: script text, beat labels and skip control.
- 13 faculty names and story taglines; **all 39 coursework quests** have Chinese and English title/story variants. Objectives, task markers, grades, countdowns, quest journal and reward notifications follow the selected locale.
- NPC and campaign storyline data already had `zh/en` choices; the quest/endings tabs now also follow the locale.
- Post-course Gomoku/cards/social game labels, scoring, refresh text, age gate and non-colliding world signs.
- Cartoon arcade/toys, professors, gameplay scores and status prompts.
- Campus coin shop, delivery mini-game, dynamic rewards and location guide/hints.
- Four-scene DDL comedy, progress/alert subtitles and proximity prompts.
- F11 LAN/graphics UI and quality labels, maintaining raw network addresses.
- Exam navigation, instructions, grade/result chrome, timer and review labels.

### Intentional content exceptions

- The original **major exam question stems, answer options, explanations and source paper titles stay in English**: these exams were explicitly requested as English-only educational game content. Buttons/menus, timers and grading guidance are localized.
- **User-written mailbox messages, usernames, player free text and LAN IP addresses remain verbatim**; the game does not translate user content.
- Names, IDs, controller keys and third-party proper nouns may remain in their native spelling.
- This patch does not rewrite separate, unmerged feature branches; other parallel PRs should connect to `GameLanguage.choose(zh,en)` before being integrated.

## Engineering contract

- `GameLanguage.choose(zh, en)` handles original authored strings; `from_row(row,zh_key,en_key)` handles structured bilingual data.
- `set_locale` rejects changes during a signed-in session; `begin_session/end_session` are controlled by the local-account shell. No remote language service.
- Profile schema uses an additive `ui_locale` key; existing saves without the key load safely. No user records are deleted.
- Code should avoid hard-coded `English / 中文` labels, slash-separated duplicate copy, or inferring locale from operating-system language.

## QA matrix

| Case | Expected |
|---|---|
| Choose English at login | 39 English coursework titles/stories, English main UI, intro and leisure |
| Choose Chinese at login | Chinese quest HUD, picker, intro, leisure and campus notices |
| Press F10 after sign-in | No locale change, no paused game or save reset |
| Log out | Language selector becomes active again |
| Sign in with another account | Current login choice applies; separate XP/mail saves unaffected |
| Existing older profile without `ui_locale` | Login still works and receives the selected language safely |
| Exam after Chinese login | Chinese navigation and grading, **original English exam questions** |
| User-typed mail | Preserved exactly, never run through string translator |
| Windows x64 exported runtime | Scene loads with localization services and passes smoke tests |

Manual Windows GUI checks remain necessary for font fallback, text wrapping at 720p/1080p, every course page, message templates and any new feature PR introduced after this branch was cut.

This is original, unofficial fictional game content and is not an official NUS service.
