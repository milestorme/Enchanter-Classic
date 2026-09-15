## 1.6.6

### LF Enchanter Improvements
- Removed the automatic no-enchant reply for unmatched customer requests so misspellings and shorthand can be handled manually.
- Added configurable manual no-enchant phrases and a configurable manual rejection cooldown.
- Added outgoing-whisper detection so using a configured rejection phrase places that customer on the longer LF Enchanter cooldown.
- Kept the normal LF Enchanter anti-spam cooldown separate from the manual rejection cooldown.

### Enchant Matching
- Expanded default aliases across the Classic Era enchant list to recognize more natural player shorthand and common stat/slot wording.
- Added upgrade-safe alias merging: new built-in aliases are merged into SavedVariables without deleting aliases users have added themselves.
- Duplicate aliases are filtered case-insensitively during the merge.

### Options
- Widened the Search Patterns label column so longer option names and notes are no longer cut off.
- Kept the overall row width within the existing options panel by resizing the corresponding input fields.

## 1.6.5

### Fixed
Fixed LF Enchanter generic phrase detection so configured phrases are actually used.
Fixed phrases such as “any enchanters online” not triggering auto-whispers.
Fixed a trade tracking race condition that could allow delayed callbacks from an earlier trade to interfere with a newer trade.
Improved trade isolation so gold/enchant history is associated with the correct completed trade.
### Cleanup
Removed obsolete TBC/Surefooted/NetherRecipes code from the Classic Era build.
Removed unused tradeBothAccepted tracking code.
Removed abandoned/commented-out Options code.
Cleaned up unused and redundant code discovered during the audit.
Verified the Classic enchant database for duplicate recipe entries.
Checked addon structure, scanning, chat matching, whisper/invite handling, trade tracking, history and options logic.