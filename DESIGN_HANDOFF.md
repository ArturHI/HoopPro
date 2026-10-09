# Design handoff

The screens in `HoopTrack/` and `HoopTrack Watch App/` are unstyled placeholders.
Restyle or replace them freely; everything below keeps working as long as the
views read from these objects and call these methods.

## `WorkoutSession.shared` (both apps)

Observe it with `@ObservedObject private var session = WorkoutSession.shared`.

| Read | Meaning |
|---|---|
| `session.workout` | The workout in progress (`LiveWorkout?`), `nil` when idle |
| `session.lastSummary` | Stats of the workout that just ended (`WorkoutSummary?`) |
| `session.isActive` | `true` while a workout is running |

| Call | Effect |
|---|---|
| `session.start(type:)` | Starts a workout on both devices (and video, if its toggle is on) |
| `session.logMake()` / `session.logMiss()` | Logs a shot |
| `session.undo()` | Removes the most recent shot (from either device) |
| `session.end()` | Ends the workout, shows the summary, saves it on the iPhone |
| `session.dismissSummary()` | Clears `lastSummary` (back to home) |

Screen routing is just: `workout != nil` → live screen, else
`lastSummary != nil` → summary, else home. See `ContentView.swift`.

## `LiveWorkout` (the live screen's data)

`workoutType`, `startDate`, `makes`, `misses`, `attempts`, `shootingPct`
(0–1), `currentStreak`, `bestStreak`, `lastShot`, `shots`, and
`elapsed(at:)` for the timer. For a ticking timer:

```swift
TimelineView(.periodic(from: .now, by: 1)) { context in
    Text(StatFormat.clock(workout.elapsed(at: context.date)))
}
```

## `WorkoutSummary` (the summary screen's data)

`workoutType`, `date`, `duration`, `makes`, `misses`, `attempts`,
`shootingPct` (0–1), `bestStreak`.

## Saved history (iPhone only)

```swift
@Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
```

Each `Workout` has `date`, `duration`, `workoutType`, `totalMakes`,
`totalAttempts`, `shootingPct` (0–1), `bestStreak`, and `shots`.
Workouts with zero shots are not saved. Also on each workout: `totalMisses`
and `orderedShots` (each shot has `shotNumber`, `result`, `inputSource`).

## Progress and dashboard numbers (iPhone only)

```swift
let stats = ProgressStats(workouts: workouts)            // everything
let stats = ProgressStats(workouts: workouts, type: .freeThrow)  // one type
```

| Property | Meaning |
|---|---|
| `trend` | One point per workout, oldest first: `date`, `shootingPct`, `attempts` |
| `today`, `thisWeek`, `lastWeek`, `allTime` | Totals: `workouts`, `makes`, `misses`, `attempts`, `shootingPct`, `duration` |
| `weekOverWeekChange` | This week minus last week (fraction); `nil` unless both have shots |
| `latestVsPrevious` | `latestPct`, `previousPct`, `change`; `nil` with fewer than two workouts |
| `bestShootingPct`, `longestStreak`, `mostMakes` | Personal bests, each with `value`, `date`, `workoutID`; `nil` until set |

Best shooting percentage only counts workouts with at least 10 shots.
See `TrendsView.swift`, `HistoryView.swift` and `SessionDetailView.swift`.

## Video (iPhone only)

`VideoRecorder.shared` records the back camera during a workout when its
toggle is on. Recording starts and stops with the workout by itself.

| Property | Meaning |
|---|---|
| `isEnabled` (settable) | The pre-workout "record video" toggle |
| `quality` (settable) | `.hd720`, `.hd1080`, `.uhd4K` |
| `isCameraAvailable` | `false` in the simulator |
| `state` | `.idle`, `.starting`, `.recording`, `.failed(reason)` |
| `captureSession` | Pass to `CameraPreview(session:)` to show the camera picture |

To show a preview before the workout, call `await recorder.prepare()` when
the toggle turns on and `recorder.shutDown()` when it turns off (see
`HomeView.swift`). `VideoSettings.shotOffset` is how many seconds before a
logged shot the video jumps to (default 4).

After a recorded workout: `workout.videoURL` is the file (or `nil`), and each
shot has `videoTimestamp` in seconds. Seek an `AVPlayer` there to jump to the
shot; see `VideoReviewView.swift`.

## Correcting shots (iPhone only)

```swift
workout.setResult(.made, for: shot)     // or .missed
workout.setExcluded(true, for: shot)    // "not a shot"; false restores it
try? modelContext.save()
```

Both update the workout's stats straight away. A changed shot has
`corrected == true` and `originalResult` set; an excluded shot has
`isExcluded == true`, stays in `orderedShots`, and counts toward nothing.
`ShotListSection(workout:)` is a ready-made list with these controls.

## Gestures (Watch only)

`GestureDetector.shared` logs shots by itself during a workout; views don't
need to do anything. For a settings or debug screen it exposes:

| Property | Meaning |
|---|---|
| `isEnabled` (settable) | Whether gestures log shots |
| `sensitivity` (settable) | `.low`, `.medium`, `.high` |
| `isInverted` (settable) | Swaps make and miss |
| `isAvailable` | `false` in the simulator (no motion sensors) |
| `latest` | Live rotation rates (`x`, `y`, `z`, `rollRate`) |
| `lastDetection`, `lastDetectionDate` | The most recent gesture seen |

A screen that shows `latest` outside a workout must call
`detector.begin(.debug)` on appear and `detector.end(.debug)` on disappear.
See `GestureDebugView.swift`.

## Helpers

- `StatFormat.percent(0.667)` → `"67%"`, `StatFormat.clock(247)` → `"4:07"`,
  `StatFormat.signedPoints(0.05)` → `"+5 pts"`
- `WorkoutType.allCases` and `.displayName` for the type picker
- `ConnectivityManager.shared.isReachable` for a connection indicator

## Adding files

New Swift files need to be in the Xcode project. Either add them through
Xcode (File → New), or drop them in the folder and run `xcodegen generate`.
