# Task record

## Match menu clock order to menu bar

- Request: Menu clock entries must follow the menu-bar clock order.
- Scope: Use the same `WorldClockPreference.visibleClocks` list for both displays.
- Acceptance: Matching system-zone clocks appear first; remaining clocks retain their configured order. Current-zone entries remain disabled and no checkmark is shown.
- Status: Delivered. Signed Release build and deep signature verification passed; packaged app restarted.
- Next action: None for implementation.

## Commit and push

- Request: Commit pending project changes and push to GitHub.
- Scope: Accumulated weather, clock, settings, layout, and approved-helper changes in this workspace, plus documentation and tests. Exclude generated builds and app bundles.
- Acceptance: Tests pass; changes committed on the current branch; origin contains the commit.
- Status: Review and verification in progress.
- Next action: Run tests, update stale README examples, commit, and push to origin.

## Disable current clock menu entry

- Request: User corrected the requirement: disable the current time zone; enable other zones for switching. No checkmark.
- Scope: Validate clock menu items against the current system time-zone identifier; keep other menu actions enabled.
- Decision: The current zone is disabled because selecting it has no effect. Other entries switch the system zone through the approved helper.
- Acceptance: Current-zone entries are disabled by AppKit menu validation, including after a system zone change; other entries are enabled; no checkmark is shown.
- Status: Implemented and delivered. Release build and deep signature verification passed; packaged app restarted. Live menu appearance not inspected.
- Checkmark removal: Delivered; signed Release build and deep signature verification passed, app restarted.
- Correction delivered: Signed Release build and deep signature verification passed; app restarted with current-zone entries disabled and other zones enabled.
- Next action: None for implementation.

## One-time approval only

- Request: User approved removal of per-switch Touch ID authentication.
- Scope: Remove LocalAuthentication from the switching path; retain SMAppService approval, signed XPC peer validation, console-user restriction, and zone validation.
- Acceptance: Selecting a menu clock calls the approved helper directly, without an app authentication prompt; signed build and existing checks pass.
- Status: Implemented and delivered. Signed Release build and deep signature verification passed; launchctl confirmed the approved helper is running; app rebuilt and restarted. LocalAuthentication no longer appears in the switching path. No time zone was changed during verification.
- Next action: None for implementation. The next menu selection uses the already-approved helper directly; post-update interactive switching was not exercised by the agent.

## Confirmed operation and repeated authentication question

- User confirmed switching works after the registration repair.
- Question: Why does each switch require authentication when a Shortcut can retain permission?
- Finding: `TimeZoneAuthorization.change` creates a new LAContext and calls evaluatePolicy for every switch. Helper approval persists separately. Per-switch authentication is an app policy, not a requirement of the already-approved helper.
- Status: Explanation provided; no authorization behavior changed. Original switching and Touch ID workflow are user-verified.
- Decision: User subsequently approved one-time approval only; see current task above. Earlier Touch ID requirements are superseded.

## Helper approval repair

- Report: User approved Date Day but switching still fails.
- Evidence: `launchctl print system/com.yongtian.DateDay.TimeZoneHelper` finds no service; BTM dump contains only the app, not its daemon. System logs report the daemon record is missing.
- Cause: Registration was conditional on `.notRegistered`; logs show status 3 (`.notFound`, verified in the SDK header), so the code skipped registration and repeatedly sent the user to settings for an absent helper.
- Fix: Attempt registration whenever the helper is not enabled; then inspect approval status. Preserve errors unrelated to approval.
- Status: Implemented, signed Release build and deep signature verification passed, packaged app restarted. Missing-helper status now attempts registration and no longer displays the approval message unless macOS actually reports requiresApproval. Live registration remains pending the next clock selection.
- Next action: Verify the signed build and restart; selecting a clock will now request registration before checking approval. Verify daemon registration in the system after the user completes approval if required.

## Touch ID time-zone authorization

- Request: Replace repeated administrator-password prompts with fingerprint approval.
- Scope: Signed SMAppService daemon, restricted XPC interface, LocalAuthentication in Date Day, build packaging and documentation.
- Acceptance: Initial macOS helper approval; subsequent menu selection uses Touch ID where available; cancel sends no privileged request; helper validates client signature and zone; signed build passes tests.
- Decision: Use Apple ServiceManagement and LocalAuthentication. Password fallback remains controlled by macOS. Helper accepts only the signed app from team CS276L7FX7 and the active console user, with no general shell interface.
- Status: Implemented and delivered in `dist/Date Day.app`. All 16 tests passed (`Test-DateDay-2026.09.19_06-01-25-+0800.xcresult`). Signed Release build, embedded daemon plist, both exact XPC signing requirements, and deep signature verification passed. Packaged app restarted. Helper approval and Touch ID interaction remain unverified.
- Packaging decision: Sign the helper target with an explicit code identifier; embed its existing signature without CodeSignOnCopy, which retained a stale identifier during verification. Clean Release rebuild confirmed the required identifier on the embedded executable.
- Next action: User selects a non-current clock, approves Date Day in macOS Login Items & Extensions, then selects the clock again and completes Touch ID. Verify changed system zone and refreshed clock order. No helper was registered or biometric approval attempted by the agent.

## Current request: direct menu clock entries

- Decision: User canceled double-click switching after two failed interactive attempts. User rejected a submenu. These instructions replace both double-click tasks below.
- Scope: Restore the standard status-item menu; show up to three configured clocks directly as label and current time. Check the current system zone. Selecting an entry requests that system zone through macOS authorization.
- Acceptance: No double-click handlers or delayed menu; direct clock entries; selection invokes authorization; current-zone order and styling refresh after success.
- Status: Implemented and delivered. Debug tests and Release build passed on 2026-09-18 at 14:57; signature verified; packaged app restarted. All double-click handling and hit-test-only code removed. Privileged system change still unverified.
- Next action: Select a clock entry in the standard menu and authorize macOS. Confirm the system zone and matching clock appearance. Desktop automation could not inspect Date Day (app lookup timed out), so this interactive verification remains open.

## Double-click a clock to set the system time zone

- Request: Double-click a configured clock to change the Mac's time zone.
- Scope: Clock hit testing, double-click handling, macOS authorization, and refresh.
- Acceptance: The clicked clock selects its configured zone; single clicks still open the menu; cancellation and errors are handled; current-zone styling and order refresh.
- Decision: Use the system administrator authorization dialog for `systemsetup`. Keep the existing time-zone settings unless the requested change requires an error to be reported.
- Status: Implemented and delivered in `dist/Date Day.app`. Privileged end-to-end verification remains open.
- Evidence: Debug tests and Release build passed on 2026-09-18. Tests cover clock hit regions, displayed order, exclusion of date/weather, empty clocks, and blinking image stability. Test result: `.derived-data/Logs/Test/Test-DateDay-2026.09.18_14-50-09--0700.xcresult`. Code signature verified; packaged app restarted.
- Behavior: Clock single-click waits for the double-click interval; right-click opens the menu immediately. Double-click requires both clicks on the same clock. Authorization cancellation is silent; errors or a system zone mismatch show an alert. Automatic zone selection is not disabled.
- Next action: User double-clicks a non-current clock and authorizes macOS; confirm the system zone, reordered bold clock, and blinking colon. The actual authorization and system change have not been exercised automatically.
- Dependency: A real system change requires the user's macOS administrator authorization. Do not change the time zone during automated checks.

## Double-click follow-up

- Report: Rapid double-click does nothing; moving the pointer then opens the menu.
- Scope: Replace status-button tracking with a dedicated mouse-event view, use timestamps and matching clock IDs to recognize double-clicks, and cancel the delayed menu action.
- Acceptance: Each mouse-up is handled directly without waiting for pointer movement. Two clicks on the same clock suppress the menu and invoke the zone change.
- Status: Implemented and delivered. Release build and signature verification passed; packaged app restarted. Interactive gesture and authorization remain unverified.
- Next action: Double-click a non-current clock in the running menu bar; confirm authorization opens without moving the pointer and no menu appears after the double-click.
