# AGENTS.md

## 1. Project Identity

This repository contains a multi-game multiplayer platform currently built with:

* Flutter / Dart for the mobile application
* Node.js / Express for the backend
* Socket.IO for real-time multiplayer communication
* MongoDB / MongoDB Atlas for persistent data

The application is currently named **Partner Play**, but the product name may change later.

The platform is designed primarily for kids and casual players.

The product should feel:

* Friendly
* Colorful
* Playful
* Cartoon-inspired
* Simple to understand
* Fast
* Smooth
* Lightweight
* Responsive
* Easy to extend with new games

The application is not limited to two-player games.

Each game can define its own supported player count.

Examples:

* Tic Tac Toe → 2 players
* Four in a Row → 2 players
* Ludo → potentially 2–4 players
* Carrom → potentially 2–4 players
* Single-player games → 1 player

Do not assume that every game has the same player count, orientation, interaction model, timer rules, or game structure.

---

# 2. Core Product Principles

Always prioritize the following:

1. Correctness
2. User experience
3. Reliability
4. Performance
5. Maintainability
6. Scalability
7. Simplicity

Do not optimize only for fewer lines of code.

Do not optimize only for fewer files.

Do not optimize only for the smallest possible implementation.

The goal is:

> Simple architecture + reusable code + correct behavior + good performance.

Avoid unnecessary complexity, but do not sacrifice architecture merely to make the implementation shorter.

---

# 3. Understand Before Changing

Before modifying code:

1. Inspect the existing project structure.
2. Inspect related screens/components.
3. Inspect existing services and utilities.
4. Inspect existing state-management patterns.
5. Inspect API and Socket.IO patterns.
6. Inspect reusable components before creating new ones.
7. Read relevant documentation under `docs/`.
8. Understand why the existing implementation exists.
9. Determine whether the requested functionality already partially exists.
10. Plan the smallest appropriate change.

Never blindly create a new implementation when an existing implementation can reasonably be reused or extended.

Do not rewrite unrelated working code.

Do not refactor large parts of the application unless the task actually requires it.

---

# 4. Game Platform Architecture

The application is a platform containing multiple games.

The architecture must allow new games to be added without repeatedly rewriting platform-level systems.

The following systems should remain reusable across games whenever possible:

* Authentication
* User profile
* Friends
* Friend requests
* Matchmaking
* Game requests
* Socket connection
* Game sessions
* Temporary chat
* Timers
* Reconnection
* API client
* Error handling
* Loading states
* Navigation
* Common UI components
* Analytics/logging if introduced later

Game-specific logic must remain isolated from platform-wide functionality.

Preferred conceptual architecture:

```text
UI
  ↓
Presentation / State
  ↓
Game Engine / Game Logic
  ↓
Services
  ↓
API / Socket
  ↓
Backend
  ↓
Database
```

Do not place complex game rules directly inside Flutter widgets.

---

# 5. Game Metadata

Games should be represented using structured metadata rather than repeatedly hardcoding game information in UI code.

A game definition may include:

* id
* name
* description
* icon/image
* supported player count
* supported modes
* supports bot
* supports online play
* supports offline play
* supports chat
* supports turn timer
* default timer
* orientation
* local interaction type
* availability/status

Example conceptual structure:

```text
GameDefinition

├── id
├── name
├── description
├── asset
├── supportedPlayerCounts
├── supportedModes
├── supportsBot
├── supportsChat
├── supportsTimer
├── defaultTimer
├── orientation
├── localInteractionType
└── status
```

The UI should render game cards/lists from this data whenever practical.

Avoid duplicating game metadata across multiple screens.

---

# 6. Game Modes

A game may support one or more of the following modes:

* Offline
* Online Random
* Online Friend
* Bot

Do not assume every game supports every mode.

A game must explicitly define which modes it supports.

---

# 7. Offline Multiplayer

Offline means the game must work without internet connectivity.

Offline multiplayer may use different interaction models.

## 7.1 Shared Device / Simultaneous

Multiple players interact with the same device without necessarily passing the phone between players.

Examples:

* Tic Tac Toe
* Four in a Row
* Ludo
* Carrom

The device can be positioned between players when appropriate.

## 7.2 Pass & Play

One player interacts with the device, then passes it to another player.

The architecture must allow a game to specify its local interaction model.

Do not assume:

```text
Turn-based = Pass & Play
```

They are different concepts.

Turn-based describes game flow.

Pass & Play describes device interaction.

---

# 8. Orientation and Screen Layout

Orientation must be determined by the individual game's requirements.

Do not force every game into one global orientation.

A game may use:

* Portrait
* Landscape
* Another appropriate layout strategy

Consider:

* Number of players
* Board dimensions
* Player positioning
* Controls
* Device aspect ratio
* Shared-device interaction
* Game visibility
* Touch targets

The game should use the most appropriate layout rather than assuming the application-wide default is always correct.

---

# 9. UI / UX Direction

The application is primarily designed for kids and casual users.

The UI should therefore be:

* Colorful
* Friendly
* Cartoon-like
* Playful
* Easy to understand
* Visually engaging
* Touch-friendly
* Responsive

Avoid making the application look like a dark competitive gaming dashboard.

Do not default to:

* Dark-only gaming UI
* Excessive neon
* Overly technical visuals
* Dense information
* Complicated navigation
* Excessive gradients
* Unnecessary visual effects

Visual inspiration may be taken from the general feel of:

**Two Player Games: The Challenge by JindoBlu**

Do not directly copy copyrighted assets, branding, or proprietary designs.

Use the reference only for general product direction such as:

* Playfulness
* Cartoon-style presentation
* Friendly game cards
* Simple navigation
* Game-focused UI
* Easy-to-understand interactions

---

# 10. Design System

Prefer reusable design primitives.

Examples:

* App buttons
* Game cards
* Avatar widgets
* Player cards
* Dialogs
* Bottom sheets
* Loading indicators
* Empty states
* Error states
* Timer widgets
* Game status indicators
* Common text styles
* Common spacing
* Common shapes

Do not create slightly different versions of the same component without a real reason.

However, avoid creating abstractions that make simple UI harder to understand.

Reuse should improve consistency, not create unnecessary complexity.

---

# 10.1 Universal Game Visual & Result Rules

These are universal product-level rules for applicable two-player games.

Game-specific documentation may define exceptions when required by the game's player count, orientation, interaction model, or rules.

## 10.1.1 Player Identity

For standard two-player games:

* Player 1 / local user = Blue
* Player 2 / opponent = Red

Standard player colors:

* Blue: `#00ACF8`
* Red: `#FF5E57`

Player identity must remain consistent throughout the game.

### Online Games

The local user is always:

* Player 1
* Blue

The online opponent is always:

* Player 2
* Red

Do not swap the user's color based on matchmaking order.

### Bot Games

The local user is always:

* Player 1
* Blue

The bot is always:

* Player 2
* Red

The bot must always use the Red player identity in the initial product implementation.

### Local Two-Player Games

For standard two-player local games:

* Player 1 = Blue
* Player 2 = Red

---

## 10.1.2 Shared-Device Player Positioning

For games where two players interact from opposite sides of the same device:

### Portrait

* Blue / Player 1 = bottom
* Red / Player 2 = top / front-camera side

### Landscape

* Blue / Player 1 = left
* Red / Player 2 = right / camera side

These are default positioning rules for fixed-side shared-device games.

---

## 10.1.3 Pass & Play

Pass-and-play is an exception to fixed-side positioning.

If players physically pass the device:

* Do not force Blue to always remain at the bottom/left.
* Do not force Red to always remain at the top/right.
* The game may define its own interaction layout.

The underlying player identity must still remain:

* Player 1 = Blue
* Player 2 = Red

---

## 10.1.4 Turn Indicator

Every turn-based game must clearly communicate the active player.

Do not rely only on background color.

Prefer a reusable curved/semi-circular turn indicator where practical.

Examples:

* `BLUE TURN`
* `RED TURN`

The indicator should:

* Use the active player's color family.
* Clearly identify the active player.
* Update whenever the turn changes.
* Remain readable against the game background.
* Use appropriate contrast.
* Prefer a short smooth transition when the active player changes.

The turn indicator should remain useful even when the game has little or no background space.

---

## 10.1.5 Turn Indicator Position

For fixed-side shared-device games:

### Portrait

* Blue turn indicator = bottom
* Red turn indicator = top

### Landscape

* Blue turn indicator = left
* Red turn indicator = right

For pass-and-play:

* Bottom is the default position when practical.
* Game-specific placement is allowed when required.

The indicator must remain visually associated with the active player.

---

## 10.1.6 Turn Background

Where the game has sufficient surrounding background space:

* Blue turn may use the Blue color family.
* Red turn may use the Red color family.

Background color is optional.

Do not force full-screen games to change their entire background merely to communicate the turn.

Full-screen games should use a dedicated turn indicator or another clear visual indicator.

When the background and turn indicator use the same color family, use different shades/tints/contrast levels so they remain visually distinct.

---

## 10.1.7 Turn Transition

When the active player changes:

* Update the turn indicator.
* Update any turn-related background when used.
* Prefer a short smooth transition instead of an abrupt visual jump when appropriate.

Do not add unnecessary heavy animations.

---

## 10.1.8 Gameplay Controls

Do not use separate persistent Back and Restart buttons on the gameplay screen by default.

Prefer one:

* More
* Options
* Three-dot

control.

The menu may contain:

1. Exit Game
2. Restart
3. Revert — only when supported by the current game/mode

Do not show unsupported actions.

---

## 10.1.9 Revert

Revert is a game/mode capability, not a universal action.

Only expose Revert when the current game and mode support undoing the previous valid move.

For the initial product:

* Play with Local may support Revert where appropriate.
* Bot mode must not expose Revert unless explicitly supported.
* Online modes must not expose local Revert unless explicitly supported by the online game architecture/server.

When Revert is supported, it must restore:

* Relevant game state
* Previous valid move
* Active player
* Relevant turn information
* Any other state affected by the reverted move

Do not show Revert merely because a game is turn-based.

---

## 10.1.10 Game End Conditions

A game may end because of:

* Game-specific win condition
* Game-specific draw condition
* Turn timeout
* Explicit resignation
* Other game-specific terminal conditions

Leaving the game screen is NOT automatically resignation.

Closing/minimizing the application is NOT automatically resignation unless a game-specific rule explicitly requires otherwise.

A player may temporarily leave the game screen and return later.

For online games, the server determines authoritative game-ending conditions.

---

## 10.1.11 Game Result Screen

When a game reaches a final result, show a dedicated Game Result screen/state before returning to the previous game flow.

Do not immediately leave the finished game.

The result must clearly identify the outcome.

### Blue Player Wins

Use the Blue color family:

`#00ACF8`

Clearly communicate:

`BLUE PLAYER WIN`

### Red Player Wins

Use the Red color family:

`#FF5E57`

Clearly communicate:

`RED PLAYER WIN`

### Bot Wins

The bot is always Red.

When the bot wins, display:

`BOT WIN`

Use the Red color family.

### Online Opponent Wins

The online opponent is always Red.

When the online opponent wins, display:

`RED PLAYER WIN`

Use the Red color family.

### Draw

Use a neutral result treatment.

Do not identify Blue or Red as the winner when the result is a draw.

---

## 10.1.12 Result Screen Actions

The Game Result screen should provide:

* `Play Again`
* `Exit`

### Play Again

Play Again should:

* Start the same game again.
* Preserve the selected mode.
* Preserve the opponent type where applicable.
* Reset the previous game state.
* Start a fresh game.

Examples:

```text
Local → Local
Bot → Bot
Online → Online rematch/new match flow
```

### Exit

Exit should:

* Leave the finished game.
* Return to the appropriate previous game flow.
* Not restart the game.

Do not create unnecessary duplicate navigation actions.

---

## 10.1.13 Result Screen Countdown

The Game Result screen must have an automatic exit countdown.

Initial countdown:

`3 seconds`

Example:

```text
Auto exit in 3
Auto exit in 2
Auto exit in 1
```

After the countdown reaches zero, perform the same navigation behavior as `Exit`.

If the user selects:

* Play Again
* Exit

the countdown must be cancelled immediately.

The countdown must:

* Be reset for every new result.
* Stop when the result screen is disposed.
* Not continue running after navigation.
* Not create timer leaks.
* Not create duplicate timers.

---

## 10.1.14 Winning Combination Highlight

Games with a multi-piece/cell winning combination should clearly highlight the winning combination.

The original game pieces should remain visible unless the game specifically requires otherwise.

For line-based games such as Four in a Row:

* Keep winning discs/pieces in their normal appearance.
* Do NOT replace winning pieces with stars or unrelated symbols.
* Use an overlay/animation to highlight the winning combination.
* The overlay should follow the exact winning pieces/cells.
* A floating/animated white line may be used where appropriate.
* The highlight must be visible long enough to clearly communicate the winning combination.
* The highlight must not unnecessarily obscure the game pieces.

The winning highlight is visual feedback only and must not modify the underlying game state.

---

## 10.1.15 Multi-Player Games

The fixed Blue/Red rules above apply to standard two-player games.

Games supporting more than two players must define their own player-color and positioning system in their game-specific documentation.

Do not force a multi-player game into the two-player Blue/Red layout.

However, multi-player games should still maintain:

* Stable player identity
* Clear active-player indication
* Clear result state
* Consistent player representation
* Game-specific documented rules

---

## 10.1.16 Accessibility

Important game information must not be communicated through color alone.

For example:

* Blue/Red colors identify players.
* Text such as `BLUE TURN` / `RED TURN` also identifies the active player.
* Result screens clearly state the result in text.

Color should reinforce information, not be the only source of information.

---

# 11. Game Logic

Game logic must be separated from UI.

Game rules should ideally be represented through dedicated game logic/engine classes or modules.

The game engine should handle concepts such as:

* Current player
* Valid moves
* Board state
* Game state
* Win detection
* Draw detection
* Turn switching
* Game completion
* Player elimination where applicable
* Game-specific rules
* Revert/undo state where supported
* Result state where applicable

Flutter widgets should primarily:

* Display state
* Receive user interaction
* Trigger actions
* Render updated state

Do not put complex rule calculations directly inside build methods.

---

# 12. Game-Specific Documentation

Universal rules belong in this file.

Game-specific rules should be documented separately.

Preferred structure:

```text
docs/
└── games/
    ├── tic_tac_toe.md
    ├── four_in_a_row.md
    ├── ludo.md
    └── carrom.md
```

Each game document may describe:

* Rules
* Board structure
* Player count
* Modes
* Turn rules
* Win conditions
* Draw conditions
* Timer behavior
* Offline interaction
* Online synchronization
* Bot behavior
* Game-specific edge cases
* Exact game-specific visual behavior
* Game-specific exceptions to universal rules

Do not make `AGENTS.md` unnecessarily large by placing detailed rules for every individual game here.

Universal rules such as standard player identity, player colors, common turn indication, common gameplay controls, and common result-screen behavior belong in `AGENTS.md`.

If a game intentionally differs from a universal rule, the exception must be explicitly documented in that game's documentation.

---

# 13. Online Multiplayer

Online game state must be authoritative on the server.

The client must not be trusted to determine authoritative game outcomes.

The server should validate:

* Player identity
* Game session
* Player membership
* Current turn
* Move validity
* Timer/deadline
* Game status
* Resignation
* Win/loss/draw
* Allowed actions

The client should primarily:

* Render state
* Send user actions
* Display timers
* Display results
* Recover/synchronize after reconnect

Never rely on the client alone for:

* Winner determination
* Turn expiration
* Valid move validation
* Rating changes
* Final game results

For standard two-player online games:

* Local user = Player 1 / Blue
* Online opponent = Player 2 / Red

The server/session model must preserve these player roles consistently.

---

# 14. Socket.IO Architecture

Socket.IO is used for real-time communication.

Avoid unnecessary polling when Socket.IO can provide the required real-time behavior.

Prefer event-driven communication.

Examples of possible events:

```text
matchmaking:join
matchmaking:matched
game:join
game:state
game:move
game:turn
game:timer
game:ended
game:resign
chat:message
chat:cleared
game:reconnect
game:sync
```

Actual event names may differ.

Do not create events unnecessarily.

Each event should have a clear responsibility.

Keep payloads small and intentional.

Game result events/state should clearly communicate the authoritative final result to both clients.

---

# 15. Socket Connection Discipline

Avoid:

* Multiple socket connections for the same user/session
* Duplicate event listeners
* Listeners registered repeatedly during rebuilds
* Unremoved listeners
* Unnecessary reconnect loops
* Unnecessary socket traffic

Always clean up:

* Event listeners
* Streams
* Timers
* Controllers
* Subscriptions
* Socket listeners
* Other resources with lifecycle ownership

A widget rebuild must not accidentally create another socket listener.

---

# 16. Game Session / Room

"Room" is primarily an internal backend/session concept.

It does not necessarily mean the user must see a "Create Room" UI.

A game session should identify:

* Game
* Players
* Player roles
* Current state
* Current turn
* Turn deadline
* Game status
* Created time
* Relevant configuration

For standard two-player sessions:

* Local user should be represented as Player 1 / Blue.
* Opponent should be represented as Player 2 / Red.

The server owns the authoritative session state.

Do not persist temporary session information in MongoDB unless there is a real product requirement.

---

# 17. Random Online Matchmaking

Random online flow:

```text
Play Online
    ↓
Find Opponent
    ↓
Matched
    ↓
Game Session
    ↓
Game
```

The matchmaking system should:

* Avoid matching a user with themselves
* Prevent duplicate active matchmaking entries
* Remove users when matched
* Handle disconnects
* Handle cancellation
* Handle stale matchmaking entries
* Create the appropriate game session

Do not unnecessarily persist matchmaking state in MongoDB.

In-memory/server-managed state should be preferred for temporary matchmaking state when appropriate.

For standard two-player games, the local user should become Player 1 / Blue and the matched opponent should become Player 2 / Red.

---

# 18. Friend System

Users can:

* Send friend requests
* Accept friend requests
* Reject friend requests
* View friends
* Send game requests to friends

Persistent friendship data belongs in MongoDB.

Do not store temporary game chat as friendship data.

---

# 19. Friend Game Requests

A friend can send a game request containing:

* Game
* Player configuration if required
* Turn duration where supported

Flow:

```text
Friend
  ↓
Game Request
  ↓
Accept
  ↓
Game Session
  ↓
Game + Temporary Chat
```

The requested turn duration must be shared by both players.

For standard two-player friend games:

* Requesting/local user = Player 1 / Blue
* Friend/opponent = Player 2 / Red

The game request must not silently swap player identity.

---

# 20. Turn Timer

Online games may use a per-turn timer.

Example:

```text
Player 1 → 1 hour

Player 2 → 1 hour

Player 1 → 1 hour

Player 2 → 1 hour
```

The timer is per turn, not necessarily the total game duration.

For friend games, the requesting player may choose a custom duration where supported.

Random online games use predefined/default durations.

The server must store/track the authoritative turn deadline.

The client timer is only a visual representation.

The client must never be trusted to decide:

> "My timer reached zero, therefore I won."

The server determines expiration.

When the active player changes, the client should update the common turn indicator accordingly.

---

# 21. Game End Conditions

A game may end because of:

1. Game-specific win condition
2. Game-specific draw condition
3. Turn timeout
4. Explicit resignation
5. Other game-specific terminal conditions

Leaving the game screen is NOT automatically resignation.

Closing/minimizing the application is NOT automatically resignation.

A player may temporarily leave the game screen and return later.

If the player is still within the active turn deadline, the game continues.

For online games, the server determines authoritative game-ending conditions.

After a game reaches a terminal result, the game should transition into its Game Result state/screen.

The result state should clearly identify:

* Winner
* Loss
* Draw
* Timeout
* Resignation
* Other game-specific terminal result

The result screen must not be confused with simply leaving the game screen.

---

# 22. Backgrounding and Reconnection

When a user:

* Minimizes the app
* Switches apps
* Leaves the game screen temporarily
* Loses network connection
* Reopens the app

the game should not automatically end unless game rules explicitly require it.

The server continues the game timer.

When the client reconnects:

1. Authenticate/re-establish session.
2. Identify active game.
3. Request/synchronize current game state.
4. Receive authoritative state.
5. Recalculate/display remaining time based on server deadline.
6. Resume UI.

Never reset the timer merely because the client reconnects.

Never trust stale client state over server state.

If the game had already ended while the client was disconnected, the client must display the authoritative final result state rather than incorrectly resuming the game.

---

# 23. Temporary In-Game Chat

Online games support temporary chat.

Chat exists only while the game session is active.

Chat is available for:

* Random online games
* Friend games

Chat is NOT available in offline mode.

Chat must NOT be permanently stored in MongoDB unless a future product decision explicitly changes this requirement.

Preferred architecture:

```text
Player A
   ↓
Socket.IO
   ↓
Active Game Session
   ↓
Socket.IO
   ↓
Player B
```

Messages should remain in active memory/session state only when necessary.

When the game ends:

* Chat must be cleared
* Temporary chat state must be destroyed
* Clients should no longer be able to send/receive game chat
* No unnecessary database write should occur

Do not store chat merely for convenience.

The goal is to keep MongoDB Atlas usage low.

---

# 24. Persistent Data

MongoDB should primarily contain long-lived product data.

Potential persistent data includes:

* User
* Profile
* Authentication-related data
* Friends
* Friend requests
* Wins
* Losses
* Games played
* Rating
* Other required persistent statistics

Avoid persisting temporary data unnecessarily.

Temporary data should generally remain outside MongoDB when possible:

* Active game state
* Temporary chat
* Matchmaking queue
* Socket session
* Current turn timer state
* Temporary connection state

Do not introduce unnecessary collections.

---

# 25. Leaderboard

There is currently NO leaderboard requirement.

Do not introduce:

* Leaderboard collection
* Global rankings
* Ranking history
* Leaderboard APIs
* Leaderboard UI

unless explicitly requested later.

Profile rating is separate from a leaderboard.

---

# 26. User Profile

The profile may contain:

* Username
* Avatar
* Wins
* Losses
* Games played
* Rating

Do not add unnecessary profile fields unless required.

Statistics should be updated from authoritative game results.

Clients must not be allowed to arbitrarily modify:

* Wins
* Losses
* Rating
* Games played

---

# 27. Authentication

Authentication may eventually support:

* Email
* Phone
* Guest

The exact verification mechanism is not fixed unless explicitly documented elsewhere.

Do not assume a verification strategy without a product requirement.

Authentication must be designed so additional login methods can be introduced later without rewriting the entire application.

Never trust client-provided user identity.

---

# 28. Bot

The application currently requires one simple bot implementation.

Do NOT create:

* Easy bot
* Medium bot
* Hard bot

as separate versions unless explicitly requested.

The initial bot should be simple and maintainable.

However, the architecture should avoid making future bot improvements unnecessarily difficult.

Bot logic must remain separate from UI.

For standard two-player games:

* Local user = Player 1 / Blue
* Bot = Player 2 / Red

The bot must use the Red player identity.

When the bot wins, the Game Result state should identify the result as:

`BOT WIN`

and use the Red color family.

---

# 29. Flutter Architecture

Use Flutter idiomatically.

Prefer clear separation between:

* UI
* State
* Models
* Services
* Repositories where useful
* Game engines
* Networking
* Socket handling

Do not introduce a state-management library merely because it is popular.

If an existing project pattern is already established, follow it unless there is a strong technical reason to change it.

Avoid putting business logic inside widgets.

Game result state and turn state should be represented in the appropriate presentation/state layer rather than being hardcoded inside visual widgets.

---

# 30. Flutter Performance

Performance is important.

Pay attention to:

* Unnecessary widget rebuilds
* Large widget trees
* Unnecessary state updates
* Expensive calculations during build
* Large images
* Unoptimized assets
* Memory leaks
* Controllers not disposed
* Streams not cancelled
* Timers not cancelled
* Socket listeners not removed
* Excessive animations
* Unnecessary network requests

Prefer efficient rendering patterns.

Do not prematurely optimize every line.

Optimize measurable or clearly expensive paths.

---

# 31. Rebuild Discipline

Do not cause the entire screen/application to rebuild when only a small section needs updating.

Prefer appropriately scoped state.

Examples:

* Timer updates should not unnecessarily rebuild the entire game screen.
* Chat messages should not rebuild unrelated UI.
* One player's state change should not unnecessarily rebuild unrelated widgets.
* Animation state should remain localized when possible.
* Turn indicator updates should not rebuild unrelated game UI.
* Result countdown updates should not unnecessarily rebuild the entire application.

However, do not create excessive micro-state abstractions solely to avoid a rebuild.

Balance performance with maintainability.

---

# 32. App Size and Dependencies

Keep the application lightweight.

Before adding a dependency, ask:

1. Is it actually required?
2. Can Flutter/Dart already solve this?
3. Is there already an existing package solving the same problem?
4. Does the dependency significantly increase app size?
5. Does it introduce unnecessary native/platform complexity?
6. Will it be maintained?
7. Is it appropriate for the project?

Avoid dependency duplication.

Do not add libraries merely because they are fashionable.

Prefer a smaller dependency graph when functionality is equivalent.

---

# 33. DRY and Reusability

Follow DRY principles, but do not force everything into one abstraction.

Good candidates for reuse:

* API client
* Socket client
* Buttons
* Cards
* Avatar
* Timer
* Dialogs
* Game metadata
* Validation
* Error handling
* Common networking utilities
* Turn indicators
* Game result UI/state components
* Game control/options menus
* Player identity/status indicators

Shared game components should be reusable when their behavior is genuinely common.

Examples:

* A reusable Turn Indicator can provide common turn presentation.
* A reusable Game Result component/state can provide common result behavior.
* A reusable Game Options menu can provide common controls.
* A reusable player indicator can maintain consistent player identity presentation.

However, do not force every game into the same visual layout.

Games may have different:

* Player counts
* Orientations
* Interaction models
* Board structures
* Result presentation
* Game rules

Avoid:

* Giant universal components
* Components with dozens of unrelated parameters
* Generic abstractions that hide simple logic
* Premature framework-like systems

Rule:

> Reuse when behavior is genuinely shared. Keep code local when abstraction would make the code harder to understand.

Reuse should improve consistency without preventing legitimate game-specific behavior.

---

# 34. Backend Architecture

Node.js/Express backend should use clear separation of responsibilities.

Prefer conceptual layers such as:

```text
Routes
  ↓
Controllers
  ↓
Services
  ↓
Repositories / Database
```

Real-time Socket.IO handling should have its own organized structure.

Avoid placing all backend logic inside one server file.

Keep:

* HTTP APIs
* Socket events
* Game logic
* Database logic
* Authentication
* Validation

appropriately separated.

---

# 35. Backend Game Authority

For online games, the backend must be authoritative.

The server should validate every important game action.

For example:

```text
Client:

"I want to move here."

Server:

"Is this player allowed to move?"

"Is it their turn?"

"Is the game still active?"

"Is the move valid?"

"Has the timer expired?"

If valid:

    Apply move

    Update state

    Determine result

    Broadcast state
```

Do not accept a client-provided winner as truth.

Do not accept a client-provided rating change as truth.

Do not accept arbitrary game state from the client.

The server must also determine the authoritative final result.

---

# 36. Validation

Validate input at the server.

Validate:

* Authentication
* IDs
* Game IDs
* Player membership
* Move payloads
* Game configuration
* Timer values
* Friend requests
* Game requests
* Chat payloads
* Socket events

Never rely exclusively on Flutter-side validation.

Client validation is for UX.

Server validation is for security and correctness.

---

# 37. Security

Never trust the client.

Protect:

* Authentication
* Authorization
* User identity
* Game actions
* Friend actions
* Game requests
* Statistics
* Rating
* Socket events

Avoid exposing secrets in the Flutter application.

Do not commit:

* API secrets
* Database credentials
* Private keys
* Production tokens
* Sensitive environment variables

Use environment configuration appropriately.

---

# 38. MongoDB Atlas Discipline

MongoDB Atlas free-tier usage should be treated as a limited resource.

Avoid unnecessary writes.

Do not write temporary chat messages.

Do not repeatedly save transient game state unless required.

Do not create unnecessary indexes or collections.

Avoid excessive polling.

Prefer event-driven updates.

Batch or combine writes where appropriate.

Only persist information that has actual product value.

---

# 39. Network Efficiency

Minimize unnecessary network traffic.

Prefer:

* Small payloads
* Event-driven updates
* Server-side authoritative state
* Socket.IO for real-time game communication
* Cached data where appropriate
* Appropriate API request frequency

Avoid:

* Repeated identical API requests
* Polling when sockets are sufficient
* Sending entire large game states when a smaller update is sufficient
* Duplicate requests caused by rebuilds
* Duplicate socket events

Do not optimize payload size so aggressively that the architecture becomes difficult to maintain.

---

# 40. Loading / Error / Empty States

Every network-dependent feature should consider:

* Loading
* Success
* Empty
* Error
* Retry
* Offline/disconnected
* Reconnecting

Do not leave the UI in an unexplained blank state.

Errors should be understandable to users.

Developer details should be logged appropriately rather than exposed directly to users.

---

# 41. Game Lifecycle

Every online game should conceptually support:

```text
Waiting / Matchmaking
        ↓
Matched
        ↓
Session Created
        ↓
Game Active
        ↓
Turn
        ↓
Move
        ↓
Next Turn
        ↓
Win / Loss / Draw / Timeout / Resign
        ↓
Game End
        ↓
Game Result State / Screen
        ↓
Play Again OR Exit
        ↓
Appropriate Game Flow
```

The exact lifecycle may differ by game.

Game-specific requirements should be documented in:

```text
docs/games/
```

The result screen/state should be shown after a terminal result and before the user leaves the finished game.

The exact ordering of backend cleanup, temporary chat destruction, statistics updates, and client navigation may vary according to architecture.

---

# 42. State Synchronization

The client must be able to reconstruct the current game state from the server.

Do not depend on receiving every historical event.

A reconnecting player should be able to request a current authoritative snapshot.

A synchronization response should contain enough information to restore the necessary UI state.

If the server reports that the game has already ended, the client must restore the final result state rather than incorrectly showing an active game.

---

# 43. Idempotency and Duplicate Actions

Network conditions may cause duplicate actions/events.

Important operations should be designed to avoid accidental duplicate effects.

Examples:

* Resign
* Move
* Friend request
* Game request
* Matchmaking join
* Restart/rematch requests where applicable

Where appropriate, use:

* Server-side validation
* Unique action/request IDs
* State checks
* Idempotent operations

Do not assume the network delivers exactly one copy of every event.

---

# 44. Timers and Time

Never rely solely on client clocks for authoritative timing.

For online games:

```text
Server:

turnStartedAt
turnDeadline
```

The client derives:

```text
remainingTime = turnDeadline - currentTime
```

The server decides whether the turn has actually expired.

Account for:

* Network latency
* Reconnection
* Backgrounding
* Client clock differences

Do not reset the timer when the app reconnects.

Do not treat the client-side countdown reaching zero as authoritative.

The same lifecycle principle applies to result-screen countdowns: they are UI timers, must be cancelled when no longer needed, and must not leak resources.

---

# 45. Resource Lifecycle

Every resource with a lifecycle must have an owner and cleanup path.

Examples:

* AnimationController
* TextEditingController
* ScrollController
* Timer
* StreamSubscription
* Socket listener
* FocusNode
* ChangeNotifier
* WebSocket/Socket connection

If something is created during a lifecycle, determine when it must be disposed.

Avoid memory leaks.

---

# 46. Assets

Optimize:

* Image dimensions
* Image formats
* Unused assets
* Duplicate assets
* Font files
* Animation files

Do not include large assets when a smaller equivalent is sufficient.

Do not add multiple fonts unnecessarily.

Prefer a consistent visual identity.

---

# 47. Animation

Animations should improve UX rather than merely consume resources.

Prefer:

* Short
* Smooth
* Purposeful
* Lightweight

Avoid excessive animation.

Avoid continuously running animations when they are not visible or required.

Pause/dispose expensive animation resources appropriately.

Game-result and winning-combination animations should remain understandable and should not obscure important game information.

---

# 48. Testing

Important game logic should be testable independently of Flutter UI.

Prioritize tests for:

* Win detection
* Draw detection
* Valid/invalid moves
* Turn switching
* Timer expiration
* Resignation
* Reconnection state
* Player validation
* Matchmaking edge cases
* Game lifecycle
* Bot decisions
* Server-side validation
* Revert behavior where supported
* Result-state behavior

Do not rely only on manually clicking through the UI.

---

# 49. Edge Cases

Always consider:

* User disconnects during turn
* User reconnects after several seconds/minutes
* User opens the game from another screen
* Both clients reconnect
* Player resigns twice
* Duplicate move arrives
* Move arrives after timeout
* Move arrives after game ended
* Friend request already exists
* Game request already accepted
* Matchmaking user disconnects
* Game session becomes stale
* Socket reconnects multiple times
* App goes into background
* App is killed
* Network changes between Wi-Fi/mobile data
* Server restarts
* Revert requested when no valid previous move exists
* Result countdown is already running
* User selects Play Again during result countdown
* User selects Exit during result countdown
* Duplicate result events arrive
* Result screen is opened after reconnect
* Game ends while the client is disconnected

Do not assume the happy path is the only path.

---

# 50. Logging and Debugging

Use useful structured logging during development.

Logs should help identify:

* User/session
* Game
* Socket event
* Error
* State transition
* Request failure

Do not log sensitive information such as:

* Passwords
* Tokens
* Secrets
* Private credentials

Avoid excessive production logging.

---

# 51. Error Handling

Errors should be handled at the appropriate layer.

Do not silently swallow errors.

Do not expose raw stack traces to users.

Prefer:

```text
Low-level error
      ↓
Handled/translated
      ↓
User-friendly message
```

Keep technical logging separate from user-facing messages.

---

# 52. Git and Change Discipline

Make focused changes.

Do not mix unrelated changes into the same task.

Before changing a file, understand its current purpose.

Avoid:

* Unrelated formatting changes
* Unnecessary renaming
* Unnecessary file movement
* Large unrelated refactors
* Removing working code without reason

If a refactor is necessary, explain why it is necessary.

---

# 53. AI Agent Behaviour

AI coding agents must behave as engineering assistants, not blind code generators.

Before coding:

1. Understand the request.
2. Inspect the repository.
3. Inspect relevant existing code.
4. Check documentation.
5. Identify reusable components.
6. Identify possible side effects.
7. Make a plan.
8. Implement the smallest appropriate solution.
9. Verify the result.

Do not immediately start creating files without understanding the existing architecture.

When implementing game UI:

* Follow the universal game rules in this file.
* Check the relevant `docs/games/` documentation.
* Reuse existing components where appropriate.
* Do not duplicate turn/result/control logic unnecessarily.
* Do not modify unrelated games.

---

# 54. Do Not Invent Requirements

Never silently invent product requirements.

If something is unspecified and materially affects architecture:

* Ask for clarification, OR
* Choose the least-assumptive implementation and clearly document the assumption.

Do not introduce features merely because they are common in similar apps.

Examples of features that should NOT be added without requirement:

* Leaderboards
* Achievements
* Chat history
* Spectator mode
* Voice chat
* Complex ranking systems
* Payments
* Push notifications
* Social feeds
* Unrequested analytics

---

# 55. Do Not Over-Engineer

Avoid unnecessary:

* Design patterns
* Abstraction layers
* Interfaces
* Factories
* Generic frameworks
* Dependencies
* Microservices
* Database collections
* Socket events

Architecture should match the actual complexity of the project.

Use advanced patterns only when they solve a real problem.

Do not create a giant universal game framework simply to make every game look architecturally identical.

---

# 56. Performance Claims

Never claim:

* "20x faster"
* "uses 50% less memory"
* "reduces network by 80%"
* "build is significantly smaller"

unless the improvement has actually been measured.

Use factual language such as:

> "This removes the duplicate API request."

or:

> "This avoids creating a second socket listener."

When performance is important, measure before and after where practical.

---

# 57. Performance Priorities

When optimizing, consider:

### CPU

Avoid unnecessary expensive calculations.

### Memory

Avoid retained listeners, controllers, timers, large objects, and unnecessary caches.

### Rendering

Avoid unnecessary rebuilds.

### Network

Avoid duplicate requests and unnecessary payloads.

### Storage

Avoid unnecessary database writes.

### App Size

Avoid unnecessary dependencies and oversized assets.

### Battery

Avoid unnecessary background work, timers, polling, and continuous animations.

---

# 58. Scalability

The initial implementation should remain simple but should not intentionally block future growth.

The architecture should make it reasonably possible to add:

* More games
* More players per game
* More bot intelligence
* More authentication methods
* More game modes
* More profile features
* More server instances later

Do not prematurely build infrastructure for hypothetical massive scale.

Build today's requirements cleanly while avoiding obvious architectural dead ends.

---

# 59. API Design

APIs should be:

* Predictable
* Validated
* Consistent
* Versionable when appropriate
* Explicit about success/failure

Use appropriate HTTP semantics.

Avoid returning unnecessary data.

Avoid APIs that expose internal database structures directly to clients.

---

# 60. Database Design

Design schemas around actual product requirements.

Prefer normalized or appropriately structured data over duplicated information when practical.

Do not store derived information unnecessarily if it can safely be calculated or maintained from authoritative data.

However, if a frequently accessed statistic is intentionally persisted for performance, document why.

Indexes should be added based on actual query patterns.

---

# 61. Environment Configuration

Environment-specific configuration must not be hardcoded into source code when it should be configurable.

Separate development and production configuration appropriately.

Never commit secrets.

Examples:

```text
DATABASE_URL
JWT_SECRET
SERVER_URL
```

Actual variable names may differ.

---

# 62. Navigation

Navigation should remain predictable.

Avoid tightly coupling game logic to navigation logic.

A game should be able to end and return to the appropriate previous screen without embedding navigation decisions throughout the game engine.

Navigation should primarily be handled at the presentation/application layer.

Game Result screens/states should provide result-specific actions such as:

* Play Again
* Exit

The result state should expose the outcome and available actions, while the appropriate presentation/application layer handles navigation.

Do not tightly couple game-engine rules directly to Flutter navigation.

---

# 63. Game Lobby

The Game Lobby should be data-driven.

A game card should ideally be generated from game metadata.

Avoid manually duplicating:

```text
Game 1 card
Game 2 card
Game 3 card
Game 4 card
```

when a reusable model/list can represent them.

The lobby may contain:

* Featured game
* Available games
* Coming soon games
* Game categories if required later

Do not implement actual gameplay when a task only requests the lobby.

---

# 64. Bottom Navigation

The application currently has three bottom navigation tabs.

Do not rewrite or redesign the bottom navigation unless explicitly requested.

When implementing another screen:

* Reuse the existing navigation structure.
* Follow the existing theme.
* Do not replace working navigation unnecessarily.

---

# 65. Product Name

The current working name is:

```text
Partner Play
```

The name may change later.

Do not tightly couple technical identifiers to the product name unless necessary.

---

# 66. Ads

The application is currently free.

Ads may be introduced later.

Do not implement an advertising system unless explicitly requested.

When ads are eventually introduced, ensure they do not unnecessarily damage:

* Game interaction
* Performance
* User experience
* Navigation
* Accessibility

---

# 67. Accessibility

Where practical, support:

* Readable text
* Adequate touch target sizes
* Clear visual hierarchy
* Meaningful labels
* Sufficient contrast
* Non-color-only indicators

Do not make important game information understandable only through color.

For game turns and results, use both:

* Color
* Text/visual state

Accessibility should be considered without compromising the playful visual identity.

---

# 68. Internationalization

Do not hardcode user-facing strings across business logic.

If internationalization is introduced later, the architecture should not make extraction unnecessarily difficult.

Do not implement a full localization system unless required.

Game result strings such as:

* BLUE PLAYER WIN
* RED PLAYER WIN
* BOT WIN
* BLUE TURN
* RED TURN

should remain presentation-layer text and should be localizable later if required.

---

# 69. Documentation

When introducing a significant architectural decision, document it.

Useful documentation locations:

```text
docs/

├── architecture/

├── games/

└── decisions/
```

Examples:

```text
docs/architecture/multiplayer.md
docs/games/tic_tac_toe.md
docs/decisions/temporary-chat.md
```

Do not document trivial implementation details unnecessarily.

---

# 70. Definition of Done

A feature is not considered complete merely because the code compiles.

Before considering a task complete, verify where applicable:

* Feature works
* Existing functionality still works
* No duplicate implementation was introduced
* Loading state works
* Error state works
* Empty state works
* Reconnection is considered
* Resources are disposed
* Socket listeners are cleaned up
* Timers are cleaned up
* No unnecessary network requests were introduced
* No unnecessary database writes were introduced
* No unnecessary dependency was added
* Relevant tests pass
* Code follows existing architecture
* UI is responsive
* UI follows the product's visual direction
* No unrelated code was modified
* Game result state works where applicable
* Result countdown is cleaned up correctly where applicable
* Play Again starts a fresh game where applicable
* Exit returns to the appropriate flow where applicable

---

# 71. Agent Verification

After implementation, agents should verify:

### Flutter

```text
flutter analyze
```

and appropriate tests/build checks when relevant.

### Backend

Run appropriate lint/test/startup checks according to the existing project configuration.

### Integration

If the task affects:

* Authentication
* Socket.IO
* Game state
* Timers
* Matchmaking
* Friend games
* Chat

perform appropriate integration-level verification rather than checking only compilation.

For game UI changes, verify:

* Correct player identity
* Correct player colors
* Correct orientation
* Correct player positioning
* Correct turn indication
* Correct result screen
* Correct result countdown
* Correct available controls

Do not claim tests were run if they were not actually run.

---

# 72. When a Requirement Conflicts With Existing Code

If the requested feature conflicts with an existing architectural decision:

1. Identify the conflict.
2. Inspect whether the old behavior is intentional.
3. Determine the smallest safe change.
4. Avoid silently breaking existing behavior.
5. Explain important tradeoffs when necessary.

Do not automatically rewrite the architecture.

If existing game behavior conflicts with an explicit universal product rule, follow the documented product rule unless the game-specific documentation explicitly defines a valid exception.

---

# 73. When Adding a New Game

When a new game is added:

1. Create game metadata.
2. Create game-specific documentation.
3. Define player count.
4. Define supported modes.
5. Define orientation.
6. Define local interaction model.
7. Define timer requirements.
8. Define win/draw conditions.
9. Define bot support if applicable.
10. Implement game logic separately.
11. Integrate with the common game/session system.
12. Add UI.
13. Add online synchronization if supported.
14. Add offline behavior if supported.
15. Add tests for core game rules.
16. Define any game-specific result behavior.
17. Define any game-specific control/revert behavior.
18. Define any game-specific visual exceptions.

Do not duplicate the entire multiplayer architecture for each game.

---

# 74. New Feature Checklist

Before adding a feature, ask:

```text
Is this required?

Does something already do this?

Can existing code be extended?

Does this belong to platform-level code or game-specific code?

Does it need persistence?

Does it need Socket.IO?

Does it need MongoDB?

Does it need a new dependency?

Does it increase app size?

Does it increase network traffic?

Does it introduce lifecycle complexity?

How does it behave offline?

How does it behave after reconnect?

What happens on failure?

What happens when the game ends?

Does it need a result state?

Does it need a timer?

Does it need cleanup/disposal?
```

---

# 75. Universal Engineering Rule

When choosing between two valid implementations, prefer the one that provides:

* Less unnecessary code
* Fewer unnecessary dependencies
* Fewer unnecessary network calls
* Fewer unnecessary database writes
* Fewer unnecessary rebuilds
* Fewer unnecessary socket events
* Lower memory usage
* Smaller assets
* Clearer responsibilities
* Better reuse
* Easier maintenance

But do NOT choose an implementation merely because it has fewer lines.

The correct goal is:

> **Small, fast, clear, reusable, reliable, and maintainable.**

These engineering principles also apply to game UI and gameplay architecture.

Prefer:

* Shared player identity rules over duplicated player-color logic
* Reusable turn-indicator behavior where genuinely shared
* Reusable result-state behavior where genuinely shared
* Capability-driven controls instead of showing every action for every game
* Game-specific implementations where games genuinely differ

Do not sacrifice clarity or legitimate game-specific requirements merely to maximize reuse.

---

# 76. Final Agent Rule

Before making a change, think:

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
Clean up
```

Never:

```text
Guess
  ↓
Generate lots of code
  ↓
Add dependencies
  ↓
Rewrite existing code
  ↓
Hope it works
```

The agent must behave like a careful engineer working on a real production project.

When uncertain, preserve existing working behavior and ask for clarification when the decision materially affects architecture or product behavior.

When implementing any game, the agent must check both:

1. Universal rules in this `AGENTS.md`
2. Game-specific rules in `docs/games/<game>.md`

The agent must not silently override a documented product rule.

Before making a significant product or architecture assumption, explain the assumption rather than inventing requirements.
