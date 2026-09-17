# Game Engineering Rules

This is a production-oriented multiplayer game.

Performance, smoothness, low memory usage, small app size, maintainability, and scalability are CORE REQUIREMENTS — not optional improvements.

## 1. Core Principles

Always prefer:

* Reusable logic over duplicated logic
* Reusable widgets/components over duplicated UI
* Shared utilities/hooks/services over repeated implementations
* Simple architecture over unnecessary abstraction
* Small, focused modules over huge files
* Efficient data structures and algorithms
* Minimal dependencies
* Lazy loading where appropriate
* Efficient asset handling
* Efficient network communication
* Minimal unnecessary rebuilds
* Minimal unnecessary API calls
* Minimal unnecessary socket events
* Minimal unnecessary state updates

Do NOT optimize by blindly reducing lines of code.

The goal is:
"Less unnecessary code + less duplication + efficient execution + maintainable architecture."

Readable and maintainable code is more important than artificially making files smaller.

---

# 2. Performance First

Treat performance as a first-class requirement.

Before implementing a feature, consider:

1. Does this cause unnecessary widget rebuilds?
2. Does this create unnecessary objects repeatedly?
3. Can this logic be shared?
4. Can this calculation be avoided or cached?
5. Can this operation be moved away from the UI/rendering path?
6. Does this cause unnecessary network requests?
7. Does this cause unnecessary socket events?
8. Does this increase memory usage?
9. Does this increase application/bundle size?
10. Can this be implemented more efficiently without making the code difficult to maintain?

Never introduce expensive operations inside frequently executed build/render paths unless necessary.

---

# 3. Flutter Performance

Use Flutter best practices.

Prefer:

* const widgets wherever possible
* small widget trees
* reusable widgets
* ListView.builder / GridView.builder for large collections
* lazy loading
* efficient state management
* selective rebuilds
* avoiding unnecessary setState calls
* avoiding rebuilding entire screens for small state changes
* disposing controllers, animations, streams and listeners correctly
* avoiding unnecessary widget/object creation
* efficient image loading and caching
* appropriately sized image assets
* avoiding oversized assets
* avoiding unnecessary animations
* keeping animations lightweight and smooth

Do not use expensive operations directly inside build().

Do not put business logic directly into UI widgets.

Keep UI, state, business logic, networking and models separated.

---

# 4. Reuse and DRY

When two or more features contain substantially similar logic:

* identify the common behavior
* extract reusable logic
* create a shared service/helper/widget/controller/model where appropriate

Do NOT copy-paste the same logic across screens.

However, do not create abstractions merely because two pieces of code look slightly similar.

Prefer meaningful reuse over premature abstraction.

Before creating a new utility/component, search the existing codebase to determine whether an equivalent already exists.

---

# 5. State Management

Use state management carefully.

Avoid global state unless the state genuinely needs to be global.

Keep local UI state local.

Use granular state updates so that changing one small piece of state does not rebuild unrelated parts of the application.

Avoid storing derived data when it can be calculated efficiently from existing state.

Avoid duplicated sources of truth.

There should be one authoritative source for important application state.

---

# 6. Networking

Networking must be efficient.

Avoid duplicate API requests.

Use caching where appropriate.

Do not fetch data repeatedly when existing data is still valid.

For Socket.IO:

* emit only necessary events
* avoid duplicate listeners
* remove listeners when no longer needed
* avoid sending unnecessarily large payloads
* use compact event payloads
* validate events
* handle reconnects safely
* avoid unnecessary broadcasting
* avoid polling when real-time events are sufficient

Never create multiple socket connections for the same logical client unless explicitly required.

---

# 7. Multiplayer Game Performance

Real-time gameplay must prioritize responsiveness.

Separate:

* UI state
* game state
* network state
* persistent data

Do not send every possible UI change to the server.

Only synchronize state that actually needs synchronization.

Keep network payloads small.

Avoid sending redundant state.

Use event-based updates where appropriate.

The client should not repeatedly request information that could be maintained through a real-time event.

The server must remain authoritative for security-sensitive game state.

---

# 8. Memory Management

Avoid memory leaks.

Always properly dispose:

* AnimationController
* TextEditingController
* ScrollController
* StreamSubscription
* timers
* socket listeners
* event listeners
* other resources requiring cleanup

Do not keep references to screens/widgets that are no longer active.

Avoid unnecessarily retaining large objects or lists in memory.

---

# 9. App Size

Keep application size as small as reasonably possible.

Before adding a dependency, ask:

* Is it actually necessary?
* Can Flutter/Dart already do this?
* Can a small internal utility solve the requirement?
* Is the dependency worth its binary size and maintenance cost?

Avoid installing libraries for trivial functionality.

Avoid duplicate libraries that solve the same problem.

Optimize images and other static assets.

Do not include unused assets.

Do not include unnecessary fonts or font weights.

Use release builds when measuring actual application size.

Never claim that the application size has improved unless it has actually been measured.

---

# 10. Dependencies

Keep dependencies minimal.

Do not install a package without first checking whether:

1. Flutter/Dart provides the functionality natively
2. an existing project dependency already provides it
3. a small internal implementation is sufficient

Do not add multiple packages for overlapping functionality.

Prefer stable, well-maintained dependencies.

---

# 11. Architecture

Keep the architecture modular but not over-engineered.

Use clear separation between:

UI
↓
State / Controllers
↓
Services
↓
API / Socket
↓
Backend

Do not mix networking logic directly into widgets.

Do not mix database logic into controllers.

Do not create unnecessary layers simply for the sake of following a pattern.

Architecture should solve an actual problem.

---

# 12. Before Writing Code

For non-trivial tasks:

1. Inspect the relevant existing code.
2. Search for reusable logic/components.
3. Identify possible duplication.
4. Consider performance implications.
5. Consider memory implications.
6. Consider app-size implications.
7. Create a short implementation plan.
8. Implement the smallest clean solution.
9. Verify that existing functionality has not been broken.

Do not rewrite unrelated code.

Do not modify large parts of the project when a small targeted change is sufficient.

---

# 13. Before Adding New Code

Always ask internally:

"Does this already exist?"

"Can existing logic be reused?"

"Can this be generalized without over-engineering?"

"Will this cause unnecessary rebuilds?"

"Will this create unnecessary network traffic?"

"Will this increase memory usage?"

"Will this increase application size?"

"Is this dependency actually necessary?"

---

# 14. Performance Measurement

Do not assume an optimization worked.

When performance matters, measure it.

Use appropriate Flutter profiling/debugging tools when necessary.

For important optimizations, compare before and after where practical.

Never invent performance numbers.

Never claim "X times faster" unless it has actually been measured.

---

# 15. Code Quality Rule

The preferred implementation is:

* simple
* reusable
* efficient
* readable
* testable
* scalable
* minimally dependent
* performance-conscious

Do not optimize for the fewest lines of code.

Optimize for the best balance of:

Performance + Memory + App Size + Maintainability + Readability.

These requirements apply to every feature unless a specific task explicitly overrides them.
