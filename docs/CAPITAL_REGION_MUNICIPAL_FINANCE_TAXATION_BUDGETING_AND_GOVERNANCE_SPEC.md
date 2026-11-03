# Capital Region — Municipal Finance, Taxation, Budgeting & Governance System

**Status:** Design proposal only; not approved for V1 implementation.  
**Authority:** The V1 content catalog remains the sole authority for operational IDs and release status. This specification adds no operational IDs and changes no catalog status.

## 1. Purpose and principles

Define a traceable municipal financial system connecting revenue, taxation, treasury, expenditure, procurement, capital investment, operating services and policy decisions. The player is a municipal decision-maker, not an unlimited source of money.

- Every monetary change has a source, destination, interval, currency/unit, actor or system cause, reference and idempotency key.
- Budget authority, cash availability, commitments, reservations and actual expenditure are distinct.
- Assessed or billed revenue is not cash collected. A proposed budget is not an appropriation; an appropriation is not a payment.
- No service, workforce, incident response or production operation is free unless an explicit funded rule says so.
- No tax rate, cost, yield, threshold, debt limit, interest rate or multiplier is guessed; unresolved numeric values remain TBD.
- Policy effects are causal, geographically attributable and explainable.
- Missing or unmodeled data is Not modeled, never silently treated as zero or healthy.
- Save/load, replay and offline catch-up must remain deterministic.

## 2. Financial domain boundaries

Maintain reconcilable but distinct views:
1. Municipal ledger: authoritative posted financial events and account balances.
2. Treasury/cash: receipts, payments, restricted cash and liquidity.
3. Budget control: appropriations, amendments, commitments, reservations and remaining authority.
4. Tax administration: taxable base, assessment, billing, collection, arrears, relief and refunds.
5. Procurement/contracts: requisitions, purchase orders, receipt, invoice and settlement.
6. Capital portfolio: projects, milestones, construction, commissioning and lifecycle obligations.
7. Operating services: staffing, energy, supplies, maintenance and recurring contracts.
8. Debt and grants: financing instruments and restricted-purpose funding, only if approved.
9. Governance: decisions, authority, approval state, effective date and measured consequences.

Do not create competing sources of truth. UI, forecasts and scorecards are read models derived from authoritative records.

## 3. Revenue model

Candidate revenue families, subject to catalog approval:
- recurring local taxes;
- fees, permits and administrative charges;
- municipal service charges where a valid service/affordability model exists;
- business or land-use receipts where defined;
- intergovernmental transfers and grants;
- asset leases or municipal commercial income;
- one-time proceeds or exceptional receipts.

Every source requires an approved type, basis, liable party/payer scope, chargeable base, assessment rule, billing cadence, collection rule, restrictions, reversals/refunds, accounting mapping and audit trail.

Keep forecast, assessed liability, billed amount, collected cash, receivable, overdue/arrears, waived, disputed, refunded and written-off amounts separate. A receipt must not be counted twice when it moves from receivable to cash. Restricted grants remain restricted. One-time revenue is never presented as recurring operating income.

## 4. Tax base, assessment and collection

Taxation is a candidate subsystem, not an assumed list of approved tax types. For each proposed tax define:
- taxable object and liable entity;
- exemption/relief eligibility and evidence;
- valuation basis and version;
- assessment cadence and effective date;
- rate/amount rule and rounding;
- billing, due date and payment channels;
- partial payment, arrears and dispute states;
- collection cost and administrative capacity;
- refund, correction, appeal and audit process.

Keep assessed value, taxable value, liability, billed balance and cash receipt distinct. Property value, business activity or household income may be used only if an authoritative corresponding simulation model exists. Policy previews must show affected groups/districts, estimated revenue range, uncertainty, collection delay and affordability risk. Evasion, avoidance, delinquency or migration effects require explicit bounded models and approval.

All rates, valuation coefficients, exemptions, penalties, collection rates and intervals remain TBD.

## 5. Accounting model and ledger invariants

Use a versioned chart of accounts and double-entry posting if the approved scope requires full accounting. Preserve the conceptual distinction among assets/cash/receivables/inventory/capital work; liabilities/payables/debt; municipal equity/net position; revenue; operating and capital expenses; and restricted funds.

Every posted journal records account, debit/credit, amount, currency, source event, entity/district/project, effective interval, posting time, policy/schema version and idempotency key.

Financial lifecycle: forecast → approved authority → commitment/reservation → invoice/obligation → payment/posting → reconciliation → period close.

Invariants:
- debits equal credits for each posted journal and currency;
- retries/replay never duplicate a posting;
- reversals use explicit compensating entries; history is not silently edited;
- source events reconcile to ledger postings;
- cash cannot be spent twice;
- restricted funds retain restrictions;
- internal transfers do not create new consolidated revenue;
- rounding residuals are explicit and deterministic;
- closed periods preserve immutable snapshots and correction history.

Whether full accrual accounting is required for V1 remains a scope decision. A simplified cash/commitment model must still be traceable and must not be mislabeled as full accrual accounting.

## 6. Treasury and liquidity

Track opening balance, receipts, payments, reserved cash, restricted cash, forecast inflows/outflows and available liquidity. Budget authority does not imply cash exists; cash does not imply budget authority exists.

Payment eligibility requires both valid spending authority and available funds. Forecasts distinguish committed, probable and speculative flows. Cash-shortfall behavior must be explicit: defer eligible payments, pause discretionary projects, protect approved critical obligations or invoke an approved financing mechanism. Never hide a deficit through automatic money creation.

## 7. Budget cycle and control

Define a versioned lifecycle:
1. baseline and revenue forecast;
2. department/service submissions;
3. capital and operating proposals;
4. affordability and risk review;
5. authorized approval;
6. appropriation by account, service, district or project;
7. commitment and reservation;
8. procurement/contract and delivery;
9. invoice verification and payment;
10. variance review, amendment and close.

Show original appropriation, amendments, commitments, paid expenditure, remaining authority, forecast-at-completion and variance. A commitment consumes available authority before cash payment; cancellation releases it exactly once. Amendments require authorized governance actions and immutable history.

Separate OPEX (recurring operations, staffing, energy, supplies and maintenance), CAPEX (approved construction/acquisition) and lifecycle cost (future operations, renewal, maintenance and decommissioning). Final accounting treatment remains a design decision.

## 8. Capital investment and asset lifecycle

A capital proposal records need, location/district, expected outcome, dependencies, options, estimate basis, uncertainty, funding source, delivery schedule, procurement path and lifecycle obligations.

Project stages: proposed → appraised → approved → funded → procured → contracted → in progress → inspected → commissioned → closed.

Project progress is not service capacity. A facility contributes operational capacity only after commissioning, staffing, network connection and other domain prerequisites. Track approved scope, change requests, committed/paid/forecast cost, schedule variance, defects, acceptance evidence and handover. Cancellation must reconcile unused materials, reservations, contracts and payments.

## 9. Procurement and supplier obligations

Procurement integrates with inventory, construction and district allocation:
- requisition and funding check;
- specification and supplier eligibility;
- approval and purchase order;
- delivery schedule and receiving inspection;
- accepted, rejected or partial quantities;
- invoice matching;
- payment and warranty/contract obligations.

A purchase-order approval does not create stock. Inventory increases only on validated receipt. Rejected goods, returns, deposits and partial deliveries require explicit states and ledger treatment.

## 10. Debt, borrowing and grants

Debt instruments, municipal bonds, credit lines and borrowing are not assumed V1 features. If approved later, define principal, drawdown, interest basis, payment schedule, maturity, fees, covenants, collateral/guarantees, refinancing and default consequences. Debt proceeds are financing, not operating revenue. Track principal separately from interest and fees. Borrowing cannot be an unlimited escape from poor budgeting.

Grants/transfers require source, eligibility, amount, timing, restrictions, matching obligations, reporting and clawback conditions. Restricted funds cannot be reassigned without an explicit rule.

## 11. Governance and policy decisions

Each decision records authority, proposal, rationale, affected scope, alternatives/trade-offs, review/approval state, audit evidence, effective date, sunset/review date, affected districts/cohorts/businesses/services, forecast assumptions and observed outcomes.

Candidate policy families include tax settings, service funding priorities, development incentives, fees, maintenance priorities and emergency spending rules. These remain candidates until approved in the V1 catalog.

Policy changes do not retroactively rewrite history. Apply them at a defined effective interval. Delayed effects must be modeled and displayed rather than applied instantaneously. Expose trade-offs: revenue versus affordability; tax burden versus service funding; expansion versus maintenance backlog; debt-funded investment versus repayment; district equity versus feasibility and urgency. Avoid a single opaque governance score.

## 12. Economic and social coupling

Connect finance to other systems only through explicit contracts:
- population/workforce: taxable or fee-paying bases only where authoritative;
- housing/land: assessed value only if a valuation model is approved;
- business activity: revenue and employment only from modeled activity;
- services/utilities: OPEX, staffing, inputs and delivered service reconcile;
- district allocation/crisis: reservations and incident costs post once;
- citizen needs/satisfaction: affordability and service indicators use transparent inputs;
- procurement/inventory: receipt and consumption reconcile with cash and stock;
- construction/assets: project cost and commissioned capacity remain separate.

A tax increase does not instantly create cash or alter population. Delayed behavioral effects require a separately approved bounded deterministic model. No circular same-interval feedback with satisfaction, migration or service demand.

## 13. Fiscal equity and risk

District reporting may compare revenue assessed/billed/collected, grants, allocated budget, actual expenditure, commitments, service funding/delivery, capital investment, asset condition, population/business denominator and data coverage. Do not infer unfairness from raw spending totals without demand, population, asset condition, service outcomes and coverage. Distinguish where revenue is raised, where it is spent and who receives services.

Only authored/modelled events may create fiscal shocks: revenue shortfall, cost escalation, supplier failure, infrastructure emergency, delayed grant, liquidity squeeze or repair surge. Each event requires trigger, scope, affected accounts/contracts/services, duration, response options, uncertainty, recovery condition and anti-exploit rules. No unexplained random losses or surprise debt.

## 14. Mobile-first finance experience

Portrait-phone surfaces:
- Treasury overview: available/restricted cash, near-term obligations and forecast.
- Revenue panel: forecast, assessed, billed, collected, overdue and one-time receipts.
- Budget control: appropriation, commitments, paid expenditure, remaining authority and variance.
- Department/service view: OPEX, staffing, outputs and funding gap.
- Capital projects: milestones, committed/paid/forecast cost, delay and commissioning gate.
- Tax policy simulator: affected groups/districts, assumptions, uncertainty and delayed effects.
- Debt/grants only if approved, with obligations/restrictions prominent.
- Audit drill-down: trace each figure to source events and journal entries.

Show units, currency, period, timestamps and status. Use accessible non-color-only indicators, large touch targets and localized number formatting. Forecasts distinguish assumptions from committed facts; a chart never replaces a ledger explanation.

## 15. Determinism, persistence, security and anti-exploit

Persist authoritative financial events, journals, account mappings, budget versions, commitments, reservations, payment states, tax assessments/receivables, policy decisions and project/contract references.

Use atomic transactions or equivalent commit semantics. Idempotency keys cover assessment, billing, receipt, reservation, purchase receipt, invoice, payment, reversal, budget amendment and offline catch-up. Approval, policy changes, write-offs, contract amendments and adjustments require server-side authorization and audit.

Acceptance invariants:
- billing is not collection; internal transfer is not consolidated revenue;
- commitments reduce remaining budget before payment and release once on cancellation;
- purchase orders do not create inventory before accepted receipt;
- project capacity appears only after commissioning and prerequisites;
- cash and appropriation are independently enforced;
- debt proceeds are not revenue; principal is distinct from interest;
- restricted grants cannot fund unrelated purposes;
- closed periods are immutable except traceable corrections;
- policy changes apply only from approved effective intervals;
- no nonexistent/unmodeled households or businesses enter a tax base;
- district equity cannot be gamed by deleting denominator data;
- services cannot operate without funded obligations unless explicitly allowed;
- concurrent payments cannot spend the same funds twice;
- replay/save-load/offline catch-up never duplicates events;
- all journals balance under documented rounding rules.

## 16. Acceptance scenarios

1. Assess and bill a tax: receivable rises; cash does not.
2. Collect a partial payment: receivable and cash reconcile; retry creates no duplicate.
3. Grant a waiver/refund: original liability and correction remain auditable.
4. Forecast a one-time sale: recurring revenue does not rise.
5. Approve a budget: authority changes, cash does not appear.
6. Commit a purchase: available authority decreases before payment.
7. Cancel a commitment: authority releases exactly once.
8. Receive part of an order: stock, payable and remaining order reconcile.
9. Reject damaged delivery: rejected quantity never enters usable stock.
10. Exhaust OPEX: approved pause/degradation behavior appears; no free service.
11. Propose CAPEX: service capacity does not appear before commissioning.
12. Commission a facility: asset and service systems receive one traceable event.
13. Simulate a tax change: assumptions, affected groups and uncertainty are visible.
14. Apply a policy mid-period: earlier periods retain the prior policy version.
15. Face a revenue shortfall: liquidity warnings precede unauthorized spending.
16. Attempt unrelated use of restricted grant: payment is rejected.
17. Draw approved debt: cash and liability reconcile; debt is not revenue.
18. Repay principal and interest: each posts to the correct category.
19. Allocate emergency resources: incident costs and ledger reconcile once.
20. Compare districts: denominators and coverage prevent misleading claims.
21. Replay/offline catch-up: no duplicate assessment, commitment, receipt, payment or journal.
22. Small phone viewport: treasury and approval flows remain usable.

## 17. Unresolved decisions and implementation gate

Accounting basis/depth; chart of accounts; currency/rounding; tax and fee types; taxable objects/valuation; assessment/collection cadence; exemptions; budget period/granularity; approval authority; CAPEX/OPEX treatment; procurement/supplier model; grant restrictions; debt availability/covenants; fiscal equity measures; risk-event catalog; forecast horizon/confidence; data retention; mobile device floor and performance budgets.

All rates, amounts, periods, thresholds, coefficients, debt limits, penalties, costs, weights and performance budgets remain TBD. Every decision requires rationale, owner, test method and explicit approval evidence.

Related specifications:
- [City Game Design Master](CITY_GAME_DESIGN_MASTER.md)
- [V1 Content Catalog](CAPITAL_REGION_V1_CONTENT_CATALOG.md)
- [Population, Workforce & Municipal Economy](POPULATION_WORKFORCE_MUNICIPAL_ECONOMY.md)
- [District Resource Allocation & Crisis Management](CAPITAL_REGION_DISTRICT_RESOURCE_ALLOCATION_AND_CRISIS_MANAGEMENT_SPEC.md)
- [Citizen Needs, Satisfaction & City Feedback](CAPITAL_REGION_CITIZEN_NEEDS_SATISFACTION_AND_CITY_FEEDBACK_SPEC.md)
- [Essential City Services & Utilities Atlas](CAPITAL_REGION_ESSENTIAL_CITY_SERVICES_AND_UTILITIES_ATLAS.md)

Before implementation: approve finance/tax/governance scope and catalog IDs; select accounting depth; define currency, account mapping, budget period and transactional contracts; approve policy authority; establish deterministic ledger/reconciliation tests; integrate procurement and service funding; create professional editable assets through specialist tools/plugins; verify licenses/provenance/hashes; conduct mobile UX and real-device profiling; obtain explicit approval to leave design phase.

**Evidence status:** Documentation only. No tax engine, treasury, accounting ledger, budget workflow, procurement finance, debt, policy simulation or gameplay behavior is implemented or device-tested by this document. Existing V1 IDs and statuses remain unchanged.


## Market settlement, trade revenue and procurement integration

The proposed market/order and freight lifecycle is specified in [Capital Region Market, Trade, Supply Chain & Interregional Commerce](CAPITAL_REGION_MARKET_TRADE_SUPPLY_CHAIN_AND_INTERREGIONAL_COMMERCE_SPEC.md). Quotes, accepted orders, dispatch, delivery, inspection and settlement are distinct financial recognition points. Gross proceeds, fees, freight, taxes where approved, refunds, returns and net settlement must map to auditable ledger events without double-counting receivables or cash. Municipal procurement links purchase commitments to accepted quantities and invoices; a purchase order does not create inventory. This reference approves no tax, tariff, accounting-recognition rule or new V1 trade capability.
