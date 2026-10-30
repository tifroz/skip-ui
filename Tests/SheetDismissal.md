# Sheet dismissal

## Native SwiftUI reference

`SwiftUIProbes/SheetDismissal.swift` is a standalone reference app, outside the
SkipUITests target. Add it to a new iOS app target in place of the generated app
source. It presents a large sheet, waits for it to settle, and dismisses it four
ways. Each display-link callback samples the presented view's presentation-layer
frame in window coordinates. Results are saved in `Documents/measurements.json`.

On an iPhone 17 Pro running iOS 27.0.1, measured on 2026-10-30:

| Dismissal | 50% of travel | 90% of travel | `onDismiss` |
| --- | ---: | ---: | ---: |
| Binding set to false | 110 ms | 227 ms | 517 ms |
| `withAnimation(.easeInOut(duration: 0.1))` | 117 ms | 251 ms | 521 ms |
| `withAnimation(.easeInOut(duration: 2.0))` | 126 ms | 243 ms | 513 ms |
| Transaction with `disablesAnimations = true` | No interpolated frames | No interpolated frames | 236 ms |

Times start at the dismissal request and include the wait for a display frame.
The normal sheet uses its own animation, independent of the duration passed to
`withAnimation`. The disabled-transaction case is recorded as a reference, not
as a claim of existing SkipUI transaction support for sheets.

Apple's [`sheet` documentation](https://developer.apple.com/documentation/swiftui/view/sheet(ispresented:ondismiss:content:))
does not expose a duration parameter. [`withAnimation`](https://developer.apple.com/documentation/swiftui/withanimation(_:_:))
sets the current transaction's animation; it does not document custom native
sheet timing.

## Android regression coverage

Material 3 1.4.0 uses its fast effects spring for `SheetState.hide()`. SkipUI
scopes a 3.5 duration multiplier to the programmatic hide coroutine using the
public Compose `MotionDurationScale` interface. This approximates SwiftUI's
visible travel while retaining Material's own spring settling and completion.
It does not promise an identical total duration. The multiplier composes with
the inherited system scale, including zero, and does not affect content
animations, presentation, drag settling, or Back dismissal.

No public SwiftUI-facing API or dependency version changes are required.

`SheetPresentationTests.programmaticDismissalKeepsVisibleTravelAndCompletesOnce`
uses the Compose test clock on a device to check an intermediate position near
100 ms, visible outgoing content, completion ordering, and reopening. An
immediate removal or Material's fast hide spring fails the intermediate-position
check. Test the actual rendered sheet, rather than only the animation parameters.

The original implementation failed this check because the header had already
left the screen. The updated implementation passed this test, the zero-system-scale
test, and the existing full-screen cover, Back/reopen, and drag/reopen tests on
a Pixel 9 Pro emulator running Android 16. The physical Android 17 phone could
not run Espresso because its input-injection setup calls the removed
`InputManager.getInstance` method; that runner failure precedes test assertions.
