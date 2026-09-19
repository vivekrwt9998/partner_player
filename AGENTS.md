# AGENTS.md

## 1. Project Identity

This project is a mobile multiplayer game platform built with:

* Flutter / Dart
* Node.js
* Express.js
* Socket.IO
* MongoDB / MongoDB Atlas

The product is designed for kids and casual players.

The overall experience should feel:

* Colorful
* Friendly
* Playful
* Cartoon-inspired
* Simple
* Fast
* Lightweight
* Easy to understand
* Easy to extend

The platform supports different types of games, including:

* 2-player games
* 2–4 player games
* Single-player games
* Turn-based games
* Real-time games
* Offline/local multiplayer
* Online multiplayer
* Bot-based games

Example games may include:

* Tic Tac Toe
* Four in a Row / Connect 4
* Ludo
* Carrom
* Future games

The architecture must support adding new games without rewriting platform-wide systems.

---

# 2. Core Engineering Principles

Always prioritize:

1. Correctness
2. User experience
3. Reliability
4. Performance
5. Maintainability
6. Scalability
7. Simplicity
8. Reusability

Do not optimize for clever code.

Prefer code that another developer can easily understand and maintain.

---

# 3. Understand Before Changing

Before modifying existing code:

1. Inspect the repository structure.
2. Read the relevant existing implementation.
3. Inspect related:

   * Screens
   * Widgets
   * Components
   * State management
   * Services
   * API calls
   * Socket events
   * Models
   * Navigation
   * Reusable components
   * Game documentation
4. Understand why the current implementation exists.
5. Identify reusable functionality before creating new functionality.
6. Plan the smallest appropriate change.
7. Only then implement.

Do not blindly rewrite existing code.

Do not replace working architecture simply because another implementation looks cleaner.

---

# 4. Platform Architecture

Use the following conceptual separation:

```text
UI
 ↓
Presentation / State
 ↓
Game Engine / Game Logic
 ↓
Platform Services
 ↓
API / Socket
 ↓
Backend
 ↓
Database
```

Game-specific logic must remain isolated from platform-wide functionality.

Platform-wide systems should be reusable across games.

Examples of platform-wide systems:

* Authentication
* Profile
* Friends
* Matchmaking
* Game requests
* Online sessions
* Rooms
* Socket connection
* Reconnection
* Temporary chat
* Timers
* API handling
* Error handling
* Loading states
* Navigation
* Common UI
* Result handling

Game-specific systems include:

* Board rules
* Win conditions
* Piece movement
* Legal moves
* Game state transitions
* Game-specific animations
* Game-specific interaction rules

---

# 5. Game Metadata

Game metadata should be structured and data-driven.

A game definition may contain information such as:

```text
id
name
description
asset
playerCount
supportedPlayerCounts
supportedModes
supportsBot
supportsChat
supportsTimer
defaultTimer
layoutOrientation
localInteractionType
turnIndicatorLayout
status
```

Do not duplicate game metadata across multiple screens.

Prefer one reusable source of truth.

Before adding a new field, inspect the existing model and extend it instead of creating duplicate models.

---

# 6. Game Modes

Games may support:

### Offline

Played locally without an internet connection.

### Online Random

Play against a randomly matched online player.

### Online Friend

Play against a selected friend.

### Bot

Play against a simple local/remote bot implementation.

Do not assume every game supports every mode.

Game metadata must define supported modes.

---

# 7. Offline Multiplayer Interaction Models

Do not assume:

> Turn-based = Pass & Play

These are different concepts.

### Shared Device / Simultaneous

Both players interact with the device while the game is active.

Example:

* Carrom
* Some board games

### Pass & Play

Players take turns physically passing the phone.

Example:

```text
Player 1 plays
↓
Turn ends
↓
Phone is passed
↓
Player 2 plays
```

Each game must explicitly define its local interaction model.

---

# 8. Game Layout Orientation vs Device Orientation

## 8.1 Critical Rule

**Game layout orientation and device orientation are separate concerns.**

A game may have a:

* Portrait-style layout
* Landscape-style layout
* Horizontal board
* Vertical board

without automatically changing the physical orientation of the device.

### Example

Four in a Row / Connect 4 may use a horizontal/landscape-style board:

```text
● ● ● ● ● ● ●
● ● ● ● ● ● ●
● ● ● ● ● ● ●
● ● ● ● ● ● ●
● ● ● ● ● ● ●
● ● ● ● ● ● ●
```

But opening the game must NOT automatically rotate the phone to landscape.

The device may remain:

```text
Portrait
┌─────────┐
│         │
│  Game   │
│  Board  │
│         │
└─────────┘
```

The game UI must adapt to the currently available screen dimensions.

---

## 8.2 No Game-Level Device Rotation

Games must not normally use game-specific device orientation locking/forcing such as:

```dart
SystemChrome.setPreferredOrientations(...)
```

to force the physical device into landscape or portrait.

Do not introduce device rotation logic merely because the game's visual layout is horizontal.

The game should adapt its UI to the current device orientation.

---

## 8.3 No Orientation Leakage

A game must never leave the rest of the application in a game-forced orientation.

For example:

```text
Game Detail
Portrait
   ↓
Connect 4
Portrait device + horizontal game layout
   ↓
Game finishes
   ↓
Result
Portrait
   ↓
Game Detail
Portrait
```

Never:

```text
Game Detail
Portrait
   ↓
Connect 4 forces Landscape
   ↓
Game finishes
   ↓
Game Detail remains Landscape ❌
```

Game completion, exiting, navigation, backgrounding, or returning to another screen must not cause orientation leakage.

---

## 8.4 Responsive Game Layout

Removing orientation locking alone is not sufficient.

If a game has a horizontal-style layout, its UI must still be responsive.

Consider:

* Available width
* Available height
* Safe areas
* Aspect ratio
* Board dimensions
* Player positions
* Controls
* Touch targets
* Text readability
* Turn indicators
* Animations

Do not allow:

* Cropping
* Overflow
* Unreachable controls
* Tiny unreadable text
* Overlapping player indicators
* Broken board proportions

---

## 8.5 Orientation Is Game-Specific

Each game may define its preferred **layout orientation**, but this must not automatically become a device orientation lock.

For example:

```text
Four in a Row
layoutOrientation = horizontal
deviceOrientationLock = none
```

The existing game-specific orientation requirements must be preserved where appropriate, but physical device rotation should not be introduced unless there is an explicit product requirement.

---

# 9. UI / UX Direction

The product is primarily designed for kids and casual players.

UI should feel:

* Colorful
* Friendly
* Playful
* Cartoon-like
* Approachable
* Clear
* Fun

Avoid making the product feel like:

* A dark competitive gaming dashboard
* A corporate admin panel
* A complex casino interface
* A dense professional dashboard

Reference apps may be used only for general UX inspiration.

Do not directly copy another product's visual design.

---

# 10. Design System

Create reusable visual primitives where repetition exists.

Examples:

* Buttons
* Cards
* Player identity components
* Game headers
* Turn indicators
* Result screens
* Game option menus
* Loading states
* Error states
* Empty states

Reuse should improve consistency without forcing every game into the same visual layout.

---

# 10.1 Universal Game Visual & Result Rules

## 10.1.1 Standard Two-Player Identity

For standard 2-player games:

```text
Player 1 / Local User = Blue
Player 2 / Opponent = Red
```

Use:

```text
Blue = #00ACF8
Red  = #FF5E57
```

Online:

```text
Local User = Player 1 = Blue
Opponent   = Player 2 = Red
```

Bot:

```text
Local User = Blue
Bot        = Red
```

Local 2-player:

```text
Player 1 = Blue
Player 2 = Red
```

Do not dynamically swap these identities merely because the turn changes.

---

## 10.1.2 Fixed-Side Player Positioning

For standard fixed-side shared-device 2-player games:

### Portrait layout

```text
Red / Player 2
      TOP

      GAME

Blue / Player 1
     BOTTOM
```

### Landscape-style layout

```text
Blue / Player 1 | GAME | Red / Player 2
```

However, this rule applies to the **game's logical/player layout**, not as an instruction to physically rotate the device.

---

# 10.1.3 Turn Indicator Is Required

Every turn-based game must clearly communicate whose turn it is.

The indicator should:

* Be clearly visible
* Use the active player's color family
* Include readable text
* Update immediately when the turn changes
* Have a short smooth transition
* Maintain sufficient contrast
* Not rely on color alone

Examples:

```text
BLUE TURN
RED TURN
```

or game-specific equivalent.

---

# 10.1.4 Turn Indicator Layout Must Follow Player Interaction Model

Do not use one universal physical placement rule for every game.

The indicator layout must represent how players actually interact with the device.

The reusable system should support different layouts.

### Layout A — Side By Side

Used for games where players are logically positioned on opposite sides of the game layout.

Example:

```text
┌──────────────────────────┐
│                          │
│ LEFT PLAYER      RIGHT   │
│                  PLAYER  │
│                          │
│         GAME             │
│                          │
└──────────────────────────┘
```

Rules:

* Left player indicator → left side
* Right player indicator → right side
* Left-side text → left aligned
* Right-side text → right aligned
* Indicators must remain readable
* Do not allow text to wrap unnecessarily

This applies to horizontal/side-by-side game arrangements.

---

### Layout B — Pass & Play

Used when the phone is physically passed between players.

Example:

```text
        ┌──────────────┐
        │              │
        │     GAME     │
        │              │
        │              │
        │  ─────────   │
        │   BLUE TURN  │
        └──────────────┘
```

Rules:

* Use one active turn indicator.
* Place it near the bottom center.
* Use a curved/semi-circular visual shape where appropriate.
* Text should be center aligned.
* Do not anchor it to the left or right side merely because the player color is Blue or Red.
* The indicator represents the current player, not a permanent screen side.
* It must work regardless of whether the current player is Blue or Red.

---

### Layout C — Between Players

Used when two players use the phone/game from their respective positions while the device remains between them.

Example:

```text
┌──────────────────────────┐
│                          │
│          GAME            │
│                          │
│                          │
│  BLUE TURN     RED       │
│                          │
└──────────────────────────┘
```

Rules:

* Provide two bottom-area player indicators.
* Each indicator represents one player's physical interaction position.
* Indicators should be positioned within the player's own bottom-area region.
* They must not overlap.
* Each indicator should have clear player identity.
* Text should align naturally within its own curved/semi-circular shape.
* The active player must be visually distinguishable.
* Do not assume that Blue must always occupy the same physical position if the game defines another interaction arrangement.

---

# 10.1.5 Turn Indicator Shape and Sizing

Curved/semi-circular/quarter-circle indicators may be used where they fit the game.

The visual style should feel like part of the game UI rather than a generic rectangular notification.

Important:

**Compact does not mean tiny.**

Reduce:

* Unnecessary padding
* Excessive empty curved space
* Oversized containers
* Unused margins

But preserve:

* Large readable text
* Strong contrast
* Comfortable touch/readability area
* Clear player identity
* Appropriate curved shape

Do not solve excessive empty space by simply shrinking the text.

Do not replace a required curved indicator with a generic pill/rectangle unless the game's design explicitly requires it.

---

# 10.1.6 Turn Indicator Configuration

Turn indicator behavior should be reusable and preferably configuration-driven.

Possible conceptual layouts:

```text
sideBySide
passAndPlay
betweenPlayers
```

Do not hardcode game-specific indicator positioning throughout widgets.

Prefer:

```text
Game Definition
      ↓
Interaction Model
      ↓
Turn Indicator Layout
      ↓
Reusable Turn Indicator
```

Before creating a new field such as:

```text
turnIndicatorLayout
```

inspect the existing game metadata/model.

If an equivalent field already exists, reuse or extend it.

Do not create duplicate configuration systems.

---

# 10.1.7 Turn Background

A turn-specific background treatment is optional.

Do not force the entire screen to change background color on every turn.

If a background treatment is used:

* Maintain readability
* Use the active player's color family
* Preserve sufficient contrast
* Avoid distracting animations

---

# 10.1.8 Turn Transition

Turn transitions should be:

* Short
* Smooth
* Predictable

Avoid long animations that delay gameplay.

---

# 10.1.9 Gameplay Controls

Do not permanently display unnecessary controls such as:

* Back
* Restart
* Revert

Prefer a compact:

```text
More / Options / 3-dot
```

menu.

The exact available actions depend on game capability.

Current universal order:

1. Exit Game
2. Restart
3. Revert — only when supported

Do not show Revert if the game does not support it.

---

# 10.1.10 Game End Conditions

Games may end because of:

* Win
* Draw
* Timeout
* Resignation
* Other game-specific conditions

Leaving the screen or backgrounding the app must not automatically mean resignation unless the product explicitly defines that behavior.

---

# 10.1.11 Result State

When a game ends, enter a dedicated result state before navigating away.

Examples:

```text
BLUE PLAYER WIN
RED PLAYER WIN
BOT WIN
DRAW
```

Blue result:

```text
Blue visual identity
```

Red result:

```text
Red visual identity
```

Draw:

```text
Neutral visual identity
```

The result screen should clearly communicate the outcome.

---

# 10.1.12 Result Actions

Provide:

```text
Play Again
Exit
```

Play Again should:

* Preserve game mode
* Preserve opponent where applicable
* Reset game state
* Start a fresh game
* Avoid stale state from the previous match

---

# 10.1.13 Result Countdown

If a result countdown is used:

```text
3
2
1
```

Rules:

* Start a fresh countdown for every result.
* Cancel countdown if the user selects an action.
* Stop/dispose the timer correctly.
* Never create duplicate timers.
* Avoid timer leaks.

---

# 10.1.14 Winning Combination Highlight

When highlighting a winning combination:

* Preserve the original pieces.
* Use overlay/highlight/animation.
* Do not replace original game pieces with unrelated symbols.

For Four in a Row, the original discs must remain visible.

Do not replace winning discs with stars or unrelated objects.

---

# 10.1.15 Multi-Player Games

Do not force the standard Blue/Red 2-player rules onto games with more than two players.

Multi-player games may define:

* Their own player colors
* Their own player positions
* Their own turn indicators
* Their own result presentation

These rules must be documented in the relevant game specification.

---

# 10.1.16 Accessibility

Never communicate important game state using color alone.

For example:

Bad:

```text
Only blue = current turn
```

Better:

```text
BLUE TURN
```

Use:

* Text
* Icons where useful
* Color
* Shape
* Position

together where appropriate.

---

# 11. Game Logic Must Be Separate From UI

Do not place core game rules directly inside presentation widgets.

Prefer:

```text
UI
 ↓
Game State
 ↓
Game Engine / Rules
```

The game engine should handle:

* Valid moves
* Turn changes
* Win detection
* Draw detection
* Game completion
* Reset
* Serialization where required

UI should display state rather than own the core rules.

---

# 12. Game-Specific Documentation

Maintain game-specific documentation under:

```text
docs/games/
```

Examples:

```text
docs/games/tic_tac_toe.md
docs/games/four_in_a_row.md
docs/games/ludo.md
docs/games/carrom.md
```

Game-specific exceptions should be documented there.

Do not add game-specific exceptions to universal rules unless they truly apply platform-wide.

---

# 13. Online Multiplayer

Online games must support:

* Matchmaking
* Room/session creation
* Joining
* Leaving
* Turn synchronization
* State synchronization
* Reconnection
* Error handling
* Game completion

Do not rely only on local UI state for authoritative multiplayer behavior.

---

# 14. Socket.IO

Use Socket.IO for real-time communication.

Socket events should be:

* Clearly named
* Documented
* Validated
* Idempotent where necessary

Do not create duplicate socket listeners.

Always clean up listeners when screens/services are disposed.

---

# 15. Game Session / Room

Each online game should have a clear session/room identity.

A session should contain enough information to restore or synchronize the game.

Avoid storing unnecessary data in the room.

---

# 16. Matchmaking

Matchmaking should be isolated from individual game logic.

The game should specify:

* Game ID
* Player count
* Mode
* Required capabilities

Matchmaking should handle the discovery of compatible players.

---

# 17. Friends

Friend functionality is platform-wide.

Do not implement separate friend systems for individual games.

---

# 18. Friend Game Requests

Friend game requests should be reusable across supported games.

A request should contain enough information to identify:

* Sender
* Receiver
* Game
* Mode
* Session/request state

---

# 19. Turn Timer

Turn timers should be reusable.

The server should remain authoritative for online timers.

Client timers are primarily for display.

Do not trust the client for authoritative timeout decisions.

---

# 20. Game End

Online game completion must be validated by the server.

The client should not be able to arbitrarily claim:

```text
I won
```

Server-side validation must determine valid game outcomes.

---

# 21. Background / Reconnection

Backgrounding the application should not automatically destroy a valid game session.

Handle:

* App lifecycle
* Temporary disconnect
* Reconnection
* State resynchronization
* Session expiration

Avoid creating duplicate game sessions after reconnecting.

---

# 22. Temporary Chat

Online players may have temporary game chat.

Chat should be associated with the active game/session.

Temporary chat should not automatically become permanent friendship/profile data.

Use Socket.IO for real-time delivery where appropriate.

---

# 23. Persistent Data

Persist only data that actually needs persistence.

Examples:

* User
* Profile
* Friends
* Game history where required
* Persistent statistics where required

Do not store transient gameplay state permanently unless required.

---

# 24. Leaderboard

A leaderboard is **not currently required**.

Do not build leaderboard infrastructure unless explicitly requested.

---

# 25. Profile

Profile functionality should be platform-wide.

Avoid game-specific profile implementations.

---

# 26. Authentication

Authentication must be handled centrally.

Do not implement separate authentication logic inside individual games.

Use secure authentication/session practices.

---

# 27. Bot

Bots should remain simple initially.

Architecture should allow future improvement without requiring a complete rewrite.

Do not over-engineer AI before actual product requirements exist.

---

# 28. Flutter Architecture

Prefer a clear separation between:

* Screens
* Widgets
* State
* Models
* Services
* Game engines
* Networking

Do not place large amounts of business logic inside UI widgets.

Use reusable components where appropriate.

---

# 29. Performance

Prioritize:

1. Smooth gameplay
2. Fast screen transitions
3. Efficient network usage
4. Efficient rendering
5. Reasonable memory usage
6. Minimal unnecessary rebuilds

Do not claim performance improvements without measurement.

---

# 30. Rebuild Discipline

Avoid unnecessary rebuilds.

Before calling:

```text
setState
notifyListeners
emit
state update
```

consider whether the entire widget tree actually needs to rebuild.

Use targeted state updates where practical.

---

# 31. Dependencies

Do not add a package just because it is convenient.

Before adding a dependency:

1. Check whether Flutter/Dart already provides the capability.
2. Check whether an existing project dependency already solves it.
3. Consider maintenance and bundle size.
4. Add the dependency only when justified.

---

# 32. DRY / Reuse

Reuse platform-wide behavior.

Examples:

* Turn indicators
* Result UI
* Game controls
* Player identity
* Loading
* Error states
* Network handling
* Socket lifecycle
* Timer lifecycle

However:

**Do not force every game into the exact same visual layout.**

Reuse behavior and components where appropriate while allowing game-specific presentation.

---

# 33. Backend Architecture

Backend should maintain clear layers such as:

```text
Routes
 ↓
Controllers
 ↓
Services
 ↓
Game / Domain Logic
 ↓
Database
```

Do not put all business logic inside route handlers.

---

# 34. Backend Authority

For online games, the backend/server is authoritative for:

* Valid moves
* Turn ownership
* Game outcome
* Timer expiration
* Session state
* Player membership

Never trust arbitrary client-provided game results.

---

# 35. Validation

Validate data at boundaries.

Validate:

* Request payloads
* Socket payloads
* Player identity
* Session membership
* Game state
* Move legality

Never assume the client is trustworthy.

---

# 36. Security

Protect:

* Authentication
* Authorization
* Socket events
* Game sessions
* API endpoints
* User data

Do not expose sensitive information unnecessarily.

---

# 37. MongoDB Atlas

Keep database operations efficient.

Avoid:

* Unnecessary queries
* Duplicate queries
* Loading large datasets unnecessarily
* Missing indexes for frequently queried fields

Add indexes based on actual query patterns.

---

# 38. Network Efficiency

Avoid sending unnecessary real-time events.

Prefer sending only the state/data required for synchronization.

Do not repeatedly send unchanged data.

---

# 39. Loading / Error / Empty States

Every network-dependent screen should have appropriate:

* Loading state
* Error state
* Empty state
* Retry behavior where appropriate

Do not leave users with blank screens.

---

# 40. Game Lifecycle

Every game should have a clear lifecycle:

```text
Initialize
 ↓
Ready
 ↓
Playing
 ↓
Paused / Backgrounded if applicable
 ↓
Finished
 ↓
Result
 ↓
Exit / Play Again
```

Resources must be cleaned up when the lifecycle ends.

---

# 41. State Synchronization

For online games, state synchronization must be deterministic.

Avoid:

```text
Client A thinks one thing
Client B thinks another thing
Server thinks something else
```

Use server authority and predictable state transitions.

---

# 42. Idempotency

Important actions should be safe against duplicate requests/events where applicable.

Examples:

* Join room
* Leave room
* Submit move
* Restart
* End game
* Reconnect

Do not allow duplicate socket events to create duplicate state transitions.

---

# 43. Timers

Every timer must have:

* Clear ownership
* Start condition
* Stop condition
* Disposal logic

Never leave timers running after their screen/game lifecycle ends.

---

# 44. Lifecycle Resources

Dispose:

* Timers
* Animation controllers
* Stream subscriptions
* Socket listeners
* Text controllers
* Focus nodes
* Other disposable resources

Avoid memory leaks.

---

# 45. Assets

Game assets should be:

* Appropriately sized
* Optimized
* Organized
* Reusable where possible

Do not add huge assets unnecessarily.

---

# 46. Animation

Animations should improve clarity and feedback.

Avoid excessive animation that:

* Delays interaction
* Causes frame drops
* Distracts from gameplay
* Makes UI difficult to understand

---

# 47. Testing

Test:

* Game rules
* Win conditions
* Draw conditions
* Turn switching
* Restart
* Exit
* Revert where supported
* Timers
* Socket events
* Reconnection
* Result state
* UI edge cases

For orientation/layout-sensitive games, test different device sizes and orientations.

---

# 48. Edge Cases

Consider:

* Rapid taps
* Double actions
* Network loss
* Reconnection
* App backgrounding
* App resume
* Player leaving
* Invalid moves
* Duplicate events
* Timer expiration
* Restart during animation
* Exit during game
* Result countdown interruption

---

# 49. Logging

Logs should help diagnose:

* Socket problems
* API problems
* Session problems
* Game state problems
* Unexpected lifecycle transitions

Avoid excessive production logging.

Never log sensitive information.

---

# 50. Error Handling

Errors should be:

* Predictable
* User-friendly
* Recoverable where possible

Do not expose raw backend/internal errors directly to users.

---

# 51. Git / Change Discipline

Keep changes focused.

Avoid mixing:

```text
Feature change
+
Unrelated refactor
+
Formatting entire project
+
Dependency upgrades
```

unless explicitly required.

Prefer small, reviewable changes.

---

# 52. AI Agent Behavior

AI coding agents must:

1. Read AGENTS.md.
2. Inspect existing implementation.
3. Identify relevant reusable code.
4. Understand current architecture.
5. Plan the change.
6. Implement the smallest appropriate solution.
7. Verify the result.
8. Report what changed.

Do not generate large amounts of code before understanding the repository.

---

# 53. Do Not Invent Requirements

Do not invent:

* Features
* Screens
* APIs
* Socket events
* Database fields
* UX behavior
* Game rules
* Dependencies

If something is unclear:

* Inspect existing implementation first.
* Check relevant game documentation.
* Follow established project patterns.
* Make the least-assumptive implementation.

Ask for clarification only when the ambiguity materially affects architecture or behavior.

---

# 54. Do Not Over-Engineer

Do not build infrastructure for hypothetical future requirements.

Implement what is currently required while keeping the architecture reasonably extensible.

Avoid unnecessary:

* Abstractions
* Factories
* Generic engines
* Configuration layers
* Packages
* Microservices

---

# 55. Performance Claims

Never claim:

```text
10x faster
20x faster
50% less memory
```

unless it has actually been measured.

Use measurable evidence when discussing performance.

---

# 56. Performance Priorities

Prioritize:

```text
Correctness
↓
Smooth UX
↓
Network efficiency
↓
Rendering efficiency
↓
Memory efficiency
```

Do not sacrifice correctness for premature optimization.

---

# 57. Scalability

Architecture should allow:

* More games
* More players
* More game sessions
* More matchmaking
* More friends
* More game-specific logic

without duplicating platform-wide systems.

---

# 58. API

API design should be:

* Predictable
* Consistent
* Validated
* Clearly named

Use consistent response/error structures.

---

# 59. Database

Database models should represent actual persistent requirements.

Do not duplicate the same information across multiple collections without a clear reason.

---

# 60. Environment

Keep secrets and environment-specific configuration out of source control.

Use environment variables/configuration appropriately.

---

# 61. Navigation

Navigation should remain centralized and predictable.

Games should not directly manipulate unrelated platform navigation state.

Important lifecycle rule:

```text
Entering a game
↓
Playing
↓
Game ends
↓
Result
↓
Leaving game
```

must not leak game-specific device orientation or other temporary global state into the rest of the application.

---

# 62. Lobby

The lobby should remain platform-wide.

It should use game metadata rather than hardcoded game-specific UI logic wherever practical.

---

# 63. Bottom Navigation

Bottom navigation should remain consistent across platform-level screens.

Games may use their own gameplay UI.

Do not unnecessarily show platform navigation controls inside active gameplay.

---

# 64. Product Name

Current product name may be:

```text
Partner Play
```

Treat the name as configurable until final branding is confirmed.

Do not hardcode the name unnecessarily across architecture.

---

# 65. Ads

Ads should not interfere with:

* Gameplay
* Touch controls
* Turn indicators
* Result screens
* Important game state

Avoid intrusive placements.

---

# 66. Accessibility

Maintain:

* Readable text
* Sufficient contrast
* Large enough touch targets
* Clear state communication
* Color-independent status communication

Do not use color as the only signal.

---

# 67. Internationalization

Avoid hardcoding user-facing strings directly throughout widgets.

Keep future localization in mind.

Do not build a full localization architecture unless required.

---

# 68. Documentation

Document:

* Important architecture decisions
* Game-specific rules
* Non-obvious behavior
* Exceptions
* Important socket contracts
* Important API contracts

Documentation should explain **why**, not only what.

---

# 69. Definition of Done

A feature is not complete merely because the code compiles.

Definition of Done:

* Correct behavior implemented
* Existing architecture respected
* Reusable code reused
* No unnecessary dependencies
* No unrelated rewrites
* UI verified
* Edge cases considered
* Resources disposed
* Relevant tests run
* Static analysis run where applicable
* No obvious regressions
* Documentation updated when behavior/architecture changed

---

# 70. Verification

After implementation, run the appropriate verification.

For Flutter changes, typically:

```bash
flutter analyze
```

and relevant tests.

For backend changes, run the appropriate:

```text
lint
tests
build
```

commands already used by the project.

Do not claim a test was run if it was not actually run.

---

# 71. Conflict Resolution

When requirements conflict:

1. Prefer explicit current product requirements.
2. Prefer documented game-specific requirements for game-specific behavior.
3. Prefer this AGENTS.md for universal platform rules.
4. Inspect existing architecture before deciding.
5. Avoid breaking existing working behavior.
6. If ambiguity materially affects architecture, ask for clarification.

Do not silently invent a new rule.

---

# 72. Adding a New Game

When adding a new game:

1. Define game metadata.
2. Define supported player counts.
3. Define supported modes.
4. Define local interaction model.
5. Define layout orientation.
6. Define turn indicator layout where applicable.
7. Define game rules.
8. Create isolated game logic.
9. Reuse platform systems.
10. Add game-specific documentation.
11. Add required assets.
12. Add tests.
13. Verify lifecycle and cleanup.

Do not duplicate:

* Auth
* Friends
* Matchmaking
* Chat
* Socket infrastructure
* Common result UI
* Common turn indicator infrastructure
* Common API infrastructure

unless there is a genuine game-specific requirement.

---

# 73. Feature Checklist

Before implementing a feature, ask:

```text
Is this platform-wide?
Is this game-specific?
Does something reusable already exist?
Can the existing component/model be extended?
Will this affect other games?
Does this change device orientation?
Does this change only game layout?
Does this introduce temporary global state?
Does that state get cleaned up?
```

Especially for orientation-related changes:

```text
Game layout orientation?
OR
Physical device orientation?
```

Never treat these as automatically equivalent.

---

# 74. Engineering Rule

Follow:

```text
Understand
   ↓
Inspect
   ↓
Plan
   ↓
Reuse
   ↓
Implement
   ↓
Verify
   ↓
Clean Up
```

Avoid:

```text
Guess
 ↓
Generate lots of code
 ↓
Add dependencies
 ↓
Rewrite existing systems
 ↓
Hope it works
```

---

# 75. Final Agent Rule

The goal is not to write the most code.

The goal is to make the **smallest correct, maintainable, reusable change that fits the existing architecture and product requirements.**

Always preserve existing working behavior unless the requirement explicitly asks for it to change.

When implementing game UI, distinguish between:

```text
Game's visual/layout orientation
        ≠
Physical device orientation
```

A horizontal game does not automatically mean the phone should rotate to landscape.

A game-specific visual requirement must not accidentally change the orientation or behavior of the rest of the application.
