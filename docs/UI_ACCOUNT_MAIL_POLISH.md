# Account and mailbox UI polish

Stacked on PR #89 / #88 / #86. This pass brings login, profile and local mailbox panels onto the same neutral light-glass style; reduces login title and spacing; uses consistent text colors; and makes centered panels adapt their width (and fixed height where specified) to the current viewport. Existing account storage, credentials, mail semantics, hotkeys and language service are unchanged.

Validation pending: Godot 4.4 import/parse, local login/register, profile toolbar at 960x540 and 1280x720, mailbox compose/read/delete, Chinese/English overflow and screenshot review. No real rendered screenshot or runtime test is claimed.
