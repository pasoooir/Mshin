# Adaptive junction controller

## Implemented behavior

- TrafficManager measures the number of active vehicles queued for each incoming approach of a controlled T/cross junction.
- A junction selects one incoming approach for green. Green duration grows with the observed queue and is bounded by configured minimum/maximum values.
- A competing queue causes the current green to end when its approach empties; otherwise the maximum green duration bounds how long one approach can retain service.
- Phase transitions use a 1.0-second yellow interval followed by a 0.5-second all-red clearance interval.
- The next approach is selected by accumulated waiting time, with queue size as a tie-breaker. Waiting time resets for the approach that receives green, preventing a continuously queued approach from monopolizing service.
- The existing exclusive junction-cell reservation remains an additional physical occupancy guard. It is deliberately conservative: only one vehicle may occupy the junction conflict zone at a time.
- A denied signal admission remains a hard stop. The four-second frontmost congestion recovery cannot override a red/yellow/all-red phase.

## Explicit boundaries

This slice is an adaptive approach-phase controller, not a complete turn-movement signal model. It does not yet permit compatible opposing movements to proceed simultaneously, distinguish protected left/right turns, model pedestrian phases, or perform emergency pre-emption. It also does not claim country-specific traffic-law compliance or rendered traffic-light props.

The existing exclusive reservation is retained until a tested turn-conflict matrix and swept-path/exit-clearance model can safely replace it.

## Verification

GameplaySmoke exercises:
- initial green selection and approach-specific admission;
- rejection of a competing approach during green;
- rejection during yellow and all-red;
- transition through the configured clearance intervals;
- longest-waiting approach handoff and renewed admission;
- the existing exclusive reservation and four-second frontmost-only recovery.

Static project validation checks the controller API and the behavior-test contracts. CI/runtime success must be taken from actual workflow results, not inferred from this specification.
