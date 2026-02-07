# iOS Frontend QA Checklist

## Functional

- Validate happy path, empty state, and error recovery.
- Validate offline or degraded-network behavior if applicable.
- Validate pagination, pull-to-refresh, and retry flows when present.

## Visual

- Validate spacing, typography, and token usage against design specs.
- Validate edge cases with long text, large numbers, and missing media.
- Validate safe-area behavior and keyboard avoidance.

## Accessibility

- Validate VoiceOver labels, hints, traits, and reading order.
- Validate touch target size and gesture discoverability.
- Validate dynamic type at accessibility sizes.
- Validate contrast and non-color error cues.

## Localization

- Validate string externalization for all user-facing copy.
- Validate truncation and wrapping under long localized strings.
- Validate right-to-left behavior when locale requires it.

## Performance

- Validate launch and first meaningful render for new flows.
- Validate scroll smoothness on realistic data sets.
- Validate memory behavior for image-heavy or nested list screens.
- Validate network task cancellation on screen dismissal.

## Testing

- Add unit tests for state transitions and formatter logic.
- Add UI tests for critical navigation paths and retry behavior.
- Add snapshot tests for major states when snapshot tooling exists.

## Merge Gate

- Confirm no TODO placeholders remain in production code.
- Confirm analytics and logging events match product requirements.
- Confirm crash-prone force unwraps are removed or guarded.
- Confirm build and test commands pass or document blockers clearly.
