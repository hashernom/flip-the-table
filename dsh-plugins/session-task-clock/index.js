/**
 * @local/session-task-clock — Host half.
 *
 * Contributes one client-visible session projection, `taskClock`: the durable
 * log's wall-clock boundaries, folded once per committed event.
 *
 * Why a projection and not browser arithmetic: only the Host sees the whole
 * log, so the timestamps a countdown needs — when the session began, when the
 * open turn started, how long finished turns took — cannot be reconstructed
 * from a client's paged window. The value is timestamps only; the browser half
 * ticks its own clock between events and derives every estimate from them.
 *
 * @module @local/session-task-clock
 */

/** Longest run of finished-turn durations kept for the typical value (bounded checkpoint). */
const MAX_TURN_SAMPLES = 12;

/**
 * Turns longer than this are treated as idle gaps rather than work: a session a
 * user leaves open overnight logs one multi-hour "turn", and feeding that into
 * the baseline would make every later countdown meaningless.
 */
const TURN_OUTLIER_MS = 4 * 60 * 60 * 1000;

/**
 * The median of the finished turns that look like work.
 * @param {readonly number[]} durations - finished turn durations, oldest first.
 * @returns {number | null} the baseline turn length, or null without samples.
 */
function typicalTurnMs(durations) {
  const usable = durations.filter((ms) => ms > 0 && ms <= TURN_OUTLIER_MS);
  if (usable.length === 0) return null;
  const sorted = [...usable].sort((left, right) => left - right);
  return sorted[Math.floor(sorted.length / 2)];
}

/**
 * Pass-through schema. The registry validates unit state and wire views with
 * `schema.parse`, and this plugin ships no schema library, so the unit proves
 * its own shape by construction instead: every field below is a number or null.
 */
const passthrough = { parse: (value) => value };

/**
 * One finite number, or null.
 * @param {unknown} value - candidate.
 * @returns {number | null} the value when it is a usable timestamp or duration.
 */
function asNumber(value) {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

/**
 * Public view cache. The registry publishes when `Object.is` says the raw view
 * changed, and `apply` returns the same state reference for events this unit
 * ignores, so caching one view per state object gives exactly the granularity
 * the change feed wants: one publication per boundary the UI draws.
 */
const viewCache = new WeakMap();

/**
 * Project fold state onto the wire view.
 * @param {object} state - this unit's fold state.
 * @returns {object} the client-visible value.
 */
function publicView(state) {
  const cached = viewCache.get(state);
  if (cached !== undefined) return cached;

  const durations = state.turnDurations;

  const view = {
    createdAt: state.createdAt,
    firstAt: state.firstAt,
    turns: state.turns,
    steps: state.steps,
    openTurnAt: state.openTurnAt,
    lastTurnEndAt: state.lastTurnEndAt,
    lastTurnReason: state.lastTurnReason,
    failedTurns: state.failedTurns,
    stepAt: state.stepAt,
    lastTurnMs: durations.length === 0 ? null : durations[durations.length - 1],
    avgTurnMs: typicalTurnMs(durations),
    userMessages: state.userMessages,
    assistantMessages: state.assistantMessages,
  };

  viewCache.set(state, view);
  return view;
}

/**
 * The `taskClock` unit.
 *
 * Semantics worth stating, because the tab's copy depends on them:
 * - `createdAt` is the Session header's own creation time, so a reloaded
 *   session keeps its true age.
 * - Events inherited by a fork (`seq` below the fork cut) are ignored: the
 *   counts describe the work this session itself ran.
 * - Only turn, step and message boundaries re-publish; tool traffic does not,
 *   because nothing the panel draws changes with it.
 *
 * Exported so the fold can be exercised without a running Harness.
 */
export const taskClockProjectionDefinition = {
  key: 'taskClock',
  stateVersion: 1,
  stateSchema: passthrough,
  init: (header, inheritedEventCount) => ({
    createdAt: asNumber(header === undefined ? undefined : header.createdAt),
    inheritedEventCount: typeof inheritedEventCount === 'number' ? inheritedEventCount : 0,
    firstAt: null,
    turns: 0,
    steps: 0,
    openTurnAt: null,
    lastTurnEndAt: null,
    lastTurnReason: null,
    failedTurns: 0,
    stepAt: null,
    turnDurations: [],
    userMessages: 0,
    assistantMessages: 0,
  }),
  apply: (state, event) => {
    const seq = asNumber(event.seq);
    if (seq !== null && seq < state.inheritedEventCount) return state;

    const time = asNumber(event.time);
    if (time === null) return state;

    const base = state.firstAt === null ? { ...state, firstAt: time } : state;

    switch (event.type) {
      case 'turn/start':
        return { ...base, turns: base.turns + 1, openTurnAt: time, lastTurnReason: null };
      case 'turn/end': {
        const reason = event.data !== undefined && event.data.reason !== undefined && typeof event.data.reason.kind === 'string'
          ? event.data.reason.kind
          : null;
        const durations = base.openTurnAt === null
          ? base.turnDurations
          : [...base.turnDurations, Math.max(0, time - base.openTurnAt)].slice(-MAX_TURN_SAMPLES);
        return {
          ...base,
          openTurnAt: null,
          stepAt: null,
          lastTurnEndAt: time,
          lastTurnReason: reason,
          failedTurns: reason !== null && reason !== 'completed' ? base.failedTurns + 1 : base.failedTurns,
          turnDurations: durations,
        };
      }
      case 'step/start':
        return { ...base, steps: base.steps + 1, stepAt: time };
      case 'step/end':
        return base.stepAt === null ? base : { ...base, stepAt: null };
      case 'user/message':
        return { ...base, userMessages: base.userMessages + 1 };
      case 'assistant/message':
        return { ...base, assistantMessages: base.assistantMessages + 1 };
      default:
        return base;
    }
  },
  wire: { viewSchema: passthrough, view: publicView },
};

/** Required service: the projection registry this unit registers against. */
export const inject = ['sessionProjections'];

/**
 * Host plugin body: install the unit for the lifetime of the mount.
 * @param {import('@deepseek-ai/cordis').Context} ctx - host context.
 */
export function apply(ctx) {
  ctx.effect(
    () => ctx.sessionProjections.register(taskClockProjectionDefinition),
    'session-task-clock: taskClock projection',
  );
}
