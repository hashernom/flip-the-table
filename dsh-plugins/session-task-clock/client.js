window.__ModuleLoader__.load({
	id: '@local/session-task-clock',
	factory(require) {
		const React = require('react');
		const el = React.createElement;

		/** This plugin's copy namespace. */
		const NS = 'sessionTaskClock';
		/** The tab type's identity in the right Sidebar's registry, and its body's slot key. */
		const TAB_ID = '@local/session-task-clock';
		/** The page kind the guide card opens. */
		const TAB_KIND = 'session-task-clock';
		/** This plugin's own session projection (Host half). */
		const CLOCK_KEY = 'taskClock';
		/** The todo list projection the progress estimate prefers. */
		const TODOS_KEY = 'todos';
		/** The parent-owned direct-child roster. */
		const CATALOG_KEY = 'subagentCatalog';
		/** The per-child active-turn projection, read through an existing binding. */
		const CHILD_TIMING_KEY = 'subagentTiming';

		// ── copy ────────────────────────────────────────────────────────────────
		// The shipped client has en/zh built in and the request for this plugin was
		// written in Spanish, so both dictionaries carry Spanish copy: a private
		// @local plugin has exactly one reader.
		const es = {
			'type.label': 'Tiempo de tarea',
			'guide.title': 'Tiempo de tarea',
			'guide.description': 'Reloj de la sesión y progreso estimado de la tarea en curso.',
			'label.session': 'Tiempo de sesión',
			'label.currentTurn': 'Turno actual',
			'label.avgTurn': 'Turno típico',
			'label.turns': 'Turnos',
			'label.steps': 'Pasos',
			'label.agents': 'Agentes',
			'label.main': 'Principal',
			'label.child': 'subagente',
			'label.thisSession': 'esta sesión',
			'label.stepsOf': '{done}/{total} pasos',
			'label.eta': '≈ {span} restante',
			'label.loading': 'Cargando el registro de la sesión…',
			'state.working': 'trabajando',
			'state.thinking': 'modelo respondiendo',
			'state.idle': 'en espera',
			'value.openTurn': 'en curso hace {span}',
			'value.idleFor': 'inactiva hace {span}',
			'value.turnEta': '≈ {span} dentro de lo típico',
			'value.turnOver': 'más largo que lo típico ({avg})',
			'value.sessionIdle': 'La sesión está en espera: el progreso se cumplió hasta aquí.',
			'value.noEstimate': 'Sin pasos ni turnos previos: la barra se mueve sin estimación.',
			'value.active': 'activo',
			'value.done': 'finalizado',
			'value.unknown': 'sin datos',
			'value.worked': 'trabajado {span}',
			'value.sinceStart': 'desde hace {span}',
			'value.noChildren': 'Sin subagentes en esta sesión.',
			'value.errors': '{count} con error',
			'foot.note': 'Estimación aproximada a partir del registro de la sesión; no es una programación real.',
		};
		const en = es;

		// ── formatting ──────────────────────────────────────────────────────────
		/**
		 * Replace `{name}` placeholders.
		 * @param {string} template - copy with placeholders.
		 * @param {Record<string, unknown>} vars - replacements.
		 * @returns {string} the filled line.
		 */
		function fill(template, vars) {
			return String(template).replace(/\{(\w+)\}/g, (match, name) =>
				Object.prototype.hasOwnProperty.call(vars, name) ? String(vars[name]) : match);
		}

		/**
		 * Two-digit pad.
		 * @param {number} value - 0..59.
		 * @returns {string} padded.
		 */
		function pad(value) {
			return value < 10 ? '0' + value : String(value);
		}

		/**
		 * A running clock: `mm:ss`, or `h:mm:ss` past an hour.
		 * @param {number} ms - duration.
		 * @returns {string} clock text.
		 */
		function formatClock(ms) {
			const total = Math.max(0, Math.floor(ms / 1000));
			const hours = Math.floor(total / 3600);
			const minutes = Math.floor((total % 3600) / 60);
			const seconds = total % 60;
			return hours > 0 ? hours + ':' + pad(minutes) + ':' + pad(seconds) : pad(minutes) + ':' + pad(seconds);
		}

		/**
		 * A spoken-length span: `38 s`, `4 min 12 s`, `2 h 05 min`.
		 * @param {number} ms - duration.
		 * @returns {string} span text.
		 */
		function formatSpan(ms) {
			const total = Math.max(0, Math.round(ms / 1000));
			if (total < 60) return total + ' s';
			const minutes = Math.floor(total / 60);
			const seconds = total % 60;
			if (minutes < 60) return seconds === 0 ? minutes + ' min' : minutes + ' min ' + seconds + ' s';
			const hours = Math.floor(minutes / 60);
			const rest = minutes % 60;
			return rest === 0 ? hours + ' h' : hours + ' h ' + pad(rest) + ' min';
		}

		/**
		 * Whole-percent reading, clamped.
		 * @param {number} ratio - 0..1.
		 * @returns {number} 0..100.
		 */
		function percentOf(ratio) {
			return Math.max(0, Math.min(100, Math.round(ratio * 100)));
		}

		// ── artwork ─────────────────────────────────────────────────────────────
		/**
		 * The plugin's clock glyph, in the current text colour.
		 * @param {{size?: number, className?: string}} props - size in px and a class.
		 * @returns {object} the svg element.
		 */
		function ClockGlyph(props) {
			const size = props && typeof props.size === 'number' ? props.size : 16;
			return el('svg', {
				viewBox: '0 0 16 16',
				width: size,
				height: size,
				className: props ? props.className : undefined,
				fill: 'none',
				stroke: 'currentColor',
				strokeWidth: 1.4,
				strokeLinecap: 'round',
				strokeLinejoin: 'round',
				'aria-hidden': 'true',
				focusable: 'false',
			},
				el('circle', { cx: 8, cy: 8, r: 6.1 }),
				el('path', { d: 'M8 4.4V8.1l2.5 1.5' }),
			);
		}

		// ── the estimate ────────────────────────────────────────────────────────
		/**
		 * Derive the panel's one progress reading.
		 *
		 * Three honest sources, best first:
		 * 1. The current turn's todo list (the model's own plan): completed steps
		 *    extrapolate a remaining time linearly from the session's own clock.
		 * 2. The open turn against the average finished turn: a countdown to the
		 *    average, not a promise.
		 * 3. Nothing yet: an indeterminate bar, because a number invented from no
		 *    evidence would be worse than none.
		 *
		 * @param {object | undefined} clock - the `taskClock` view.
		 * @param {unknown} todos - the `todos` projection (array or null).
		 * @param {number} now - current epoch ms.
		 * @returns {object} the reading the panel draws.
		 */
		function estimate(clock, todos, now) {
			const startAt = clock === undefined ? null
				: typeof clock.createdAt === 'number' ? clock.createdAt
				: typeof clock.firstAt === 'number' ? clock.firstAt
				: null;
			const elapsed = startAt === null ? 0 : Math.max(0, now - startAt);

			if (Array.isArray(todos) && todos.length > 0) {
				let done = 0;
				let running = 0;
				for (const item of todos) {
					if (item === null || typeof item !== 'object') continue;
					if (item.status === 'completed') done += 1;
					else if (item.status === 'in_progress') running += 1;
				}
				const total = todos.length;
				const remaining = total - done;
				return {
					mode: 'steps',
					elapsed,
					ratio: done / total,
					done,
					total,
					running,
					etaMs: done > 0 ? (elapsed * remaining) / done : null,
				};
			}

			const openAt = clock !== undefined && typeof clock.openTurnAt === 'number' ? clock.openTurnAt : null;
			const avg = clock !== undefined && typeof clock.avgTurnMs === 'number' ? clock.avgTurnMs : null;

			if (openAt !== null) {
				const runMs = Math.max(0, now - openAt);
				if (avg !== null && avg >= 1000) {
					return {
						mode: 'turn',
						elapsed,
						ratio: Math.min(1, runMs / avg),
						runMs,
						avg,
						over: runMs > avg,
						etaMs: Math.max(0, avg - runMs),
					};
				}
				return { mode: 'open', elapsed, ratio: null, runMs, avg: null, etaMs: null };
			}

			return { mode: 'idle', elapsed, ratio: null, avg, etaMs: null };
		}

		// ── the panel ───────────────────────────────────────────────────────────
		/**
		 * One labelled reading row.
		 * @param {{label: string, value: string, hint?: string}} props - row content.
		 * @returns {object} the row element.
		 */
		function Reading(props) {
			return el('div', { className: 'stc-reading' },
				el('span', { className: 'stc-readingLabel' }, props.label),
				el('span', { className: 'stc-readingValue' },
					props.value,
					props.hint === undefined ? null : el('span', { className: 'stc-readingHint' }, props.hint)),
			);
		}

		/**
		 * One agent roster row.
		 * @param {{live: boolean, name: string, mode: string, state: string, time: string}} props - row content.
		 * @returns {object} the row element.
		 */
		function AgentRow(props) {
			return el('div', { className: 'stc-agent' },
				el('span', { className: 'stc-dot', 'data-live': props.live ? 'true' : 'false' }),
				el('span', { className: 'stc-agentName' },
					props.name,
					props.mode === '' ? null : el('span', { className: 'stc-agentMode' }, props.mode)),
				el('span', { className: 'stc-agentTime' },
					el('span', { className: 'stc-agentValue' }, props.time),
					el('span', { className: 'stc-agentState' }, props.state)),
			);
		}

		/**
		 * The tab body: a live clock, an approximate progress bar, and the roster
		 * of the agent and its subagents.
		 *
		 * Every value is a projection view (Host-derived) plus this component's
		 * own one-second tick; the component subscribes to nothing itself.
		 * @param {object} props - slot kit plus this plugin's owner props.
		 * @returns {object} the panel element.
		 */
		function TaskClockBody(props) {
			const useProjection = props.useProjection;
			const useSessionStatus = props.useSessionStatus;
			const t = props.t;
			const sessionId = props.sessionId;
			const readAgentTiming = props.readAgentTiming;

			// `useTabInfo` is the sidebar-right slot's own deferred hook; guard the
			// call so a composition without that seat degrades to no tab info instead
			// of crashing the entry.
			const readTab = typeof props.useTabInfo === 'function' ? props.useTabInfo : undefined;
			const info = readTab === undefined ? undefined : readTab();
			const tab = info === undefined ? undefined : info.tab;
			const visible = tab === undefined || tab === null || tab.visible !== false;

			const clock = useProjection(CLOCK_KEY);
			const todos = useProjection(TODOS_KEY);
			const catalog = useProjection(CATALOG_KEY);
			const statuses = useSessionStatus((map) => map);

			const [now, setNow] = React.useState(() => Date.now());
			React.useEffect(() => {
				setNow(Date.now());
				if (!visible) return undefined;
				const timer = setInterval(() => setNow(Date.now()), 1000);
				return () => clearInterval(timer);
			}, [visible]);

			const loading = clock === undefined;
			const reading = estimate(clock, todos, now);
			const sessionRunning = statuses !== undefined && statuses !== null && typeof statuses.get === 'function'
				? Boolean(statuses.get(sessionId) && statuses.get(sessionId).running)
				: false;
			const openTurn = clock !== undefined && typeof clock.openTurnAt === 'number' ? clock.openTurnAt : null;
			const live = openTurn !== null || sessionRunning;
			const thinking = clock !== undefined && typeof clock.stepAt === 'number';
			const stateText = !live ? t('state.idle') : thinking ? t('state.thinking') : t('state.working');

			const stateHint = openTurn !== null
				? fill(t('value.openTurn'), { span: formatSpan(now - openTurn) })
				: clock !== undefined && typeof clock.lastTurnEndAt === 'number'
					? fill(t('value.idleFor'), { span: formatSpan(now - clock.lastTurnEndAt) })
					: '';

			// ── the bar's caption ────────────────────────────────────────────────
			let caption;
			let indeterminate = false;
			if (loading) {
				caption = t('label.loading');
				indeterminate = true;
			} else if (reading.mode === 'steps') {
				caption = fill(t('label.stepsOf'), { done: reading.done, total: reading.total });
				if (reading.etaMs !== null) caption = caption + ' · ' + fill(t('label.eta'), { span: formatSpan(reading.etaMs) });
			} else if (reading.mode === 'turn') {
				caption = reading.over
					? fill(t('value.turnOver'), { avg: formatSpan(reading.avg) })
					: fill(t('value.turnEta'), { span: formatSpan(reading.etaMs) });
			} else if (reading.mode === 'open') {
				caption = fill(t('value.openTurn'), { span: formatSpan(reading.runMs) });
				indeterminate = true;
			} else {
				caption = t('value.sessionIdle');
			}

			const ratio = reading.ratio;
			const barWidth = ratio === null
				? undefined
				: { width: (indeterminate ? 38 : percentOf(ratio)) + '%' };

			// ── readings ─────────────────────────────────────────────────────────
			const currentTurnValue = openTurn !== null
				? formatClock(now - openTurn)
				: clock !== undefined && typeof clock.lastTurnMs === 'number' ? formatSpan(clock.lastTurnMs) : '—';
			const avgValue = clock !== undefined && typeof clock.avgTurnMs === 'number' ? formatSpan(clock.avgTurnMs) : '—';
			const turnsValue = clock === undefined ? '—' : String(clock.turns);
			const errorsHint = clock !== undefined && clock.failedTurns > 0
				? ' · ' + fill(t('value.errors'), { count: clock.failedTurns })
				: undefined;

			// ── the roster ───────────────────────────────────────────────────────
			const children = Array.isArray(catalog) ? catalog : [];
			const rows = [
				el(AgentRow, {
					key: 'main',
					live: live,
					name: t('label.main'),
					mode: t('label.thisSession'),
					state: stateText,
					time: openTurn !== null ? formatClock(now - openTurn) : '—',
				}),
			];
			for (const child of children) {
				if (child === null || typeof child !== 'object' || typeof child.id !== 'string') continue;
				let timing;
				if (typeof readAgentTiming === 'function') {
					try {
						timing = readAgentTiming(child.id);
					} catch (error) {
						timing = undefined;
					}
				}
				const childStatus = statuses !== undefined && statuses !== null && typeof statuses.get === 'function'
					? statuses.get(child.id)
					: undefined;
				const activeSince = timing !== undefined && timing !== null && timing.active !== undefined && timing.active !== null
					? timing.active
					: undefined;
				const active = activeSince !== undefined || Boolean(childStatus && childStatus.running);
				const finished = timing !== undefined && timing !== null && timing.lastTurnCompleted === true;
				let workedMs = null;
				if (timing !== undefined && timing !== null && typeof timing.settledMs === 'number') {
					workedMs = timing.settledMs;
					if (activeSince !== undefined) {
						const from = typeof activeSince.since === 'number' ? activeSince.since : now;
						const through = typeof activeSince.through === 'number' ? activeSince.through : now;
						workedMs += Math.max(0, through - from);
					}
				}
				const sinceStart = typeof child.createdAt === 'number' ? Math.max(0, now - child.createdAt) : null;
				const timeText = workedMs !== null ? formatClock(workedMs) : sinceStart !== null ? formatClock(sinceStart) : '—';
				const stateLabel = active ? t('value.active') : finished ? t('value.done') : t('value.unknown');
				const detail = workedMs !== null
					? fill(t('value.worked'), { span: formatSpan(workedMs) })
					: sinceStart !== null ? fill(t('value.sinceStart'), { span: formatSpan(sinceStart) }) : '';
				rows.push(el(AgentRow, {
					key: 'child:' + child.id,
					live: active,
					name: typeof child.label === 'string' && child.label !== '' ? child.label : t('label.child'),
					mode: typeof child.mode === 'string' ? child.mode : '',
					state: stateLabel === '' ? detail : stateLabel + (detail === '' ? '' : ' · ' + detail),
					time: timeText,
				}));
			}

			return el('div', {
				className: 'stc-root',
				'data-task-clock': loading ? 'loading' : reading.mode,
				'data-live': live ? 'true' : 'false',
			},
				el('div', { className: 'stc-head' },
					el('span', { className: 'stc-caption' }, t('label.session')),
					el('span', { className: 'stc-clock' }, formatClock(reading.elapsed)),
					el('span', { className: 'stc-state' },
						el('span', { className: 'stc-dot', 'data-live': live ? 'true' : 'false' }),
						el('span', { className: 'stc-stateText' }, stateText),
						stateHint === '' ? null : el('span', { className: 'stc-stateHint' }, ' · ' + stateHint)),
				),
				el('div', { className: 'stc-progress' },
					el('div', {
						className: 'stc-bar',
						'data-indeterminate': indeterminate ? 'true' : 'false',
					}, el('div', { className: 'stc-fill', style: barWidth, 'data-over': reading.over === true ? 'true' : 'false' })),
					el('div', { className: 'stc-captionLine' },
						el('span', { className: 'stc-captionText' }, caption),
						ratio === null ? null : el('span', { className: 'stc-percent' }, percentOf(ratio) + '%'),
					),
				),
				el('div', { className: 'stc-section' },
					el(Reading, { label: t('label.currentTurn'), value: currentTurnValue }),
					el(Reading, { label: t('label.avgTurn'), value: avgValue }),
					el(Reading, { label: t('label.turns'), value: turnsValue, hint: errorsHint }),
					el(Reading, { label: t('label.steps'), value: clock === undefined ? '—' : String(clock.steps) }),
				),
				el('div', { className: 'stc-section' },
					el('span', { className: 'stc-sectionTitle' }, t('label.agents')),
					el('div', { className: 'stc-agents' }, rows),
					children.length === 0 ? el('span', { className: 'stc-empty' }, t('value.noChildren')) : null,
				),
				el('span', { className: 'stc-foot' }, t('foot.note')),
			);
		}

		/**
		 * The tab chip: the clock glyph and the title captured when the tab opened.
		 * @param {object} props - the slot kit.
		 * @returns {object} the chip content.
		 */
		function TaskClockTitle(props) {
			const readTab = typeof props.useTabInfo === 'function' ? props.useTabInfo : undefined;
			const info = readTab === undefined ? undefined : readTab();
			const tab = info === undefined ? undefined : info.tab;
			return el(React.Fragment, null,
				el(ClockGlyph, { size: 14, className: 'stc-titleGlyph' }),
				tab === undefined || tab === null ? '' : tab.title);
		}

		// ── styles ──────────────────────────────────────────────────────────────
		const CSS = [
			'.stc-root{display:flex;flex-direction:column;gap:14px;height:100%;overflow:auto;padding:16px 16px 20px;color:var(--dsw-alias-label-primary);font-size:13px;line-height:1.45}',
			'.stc-head{display:flex;flex-direction:column;gap:2px}',
			'.stc-caption{font-size:11px;letter-spacing:.04em;text-transform:uppercase;color:var(--dsw-alias-label-secondary)}',
			'.stc-clock{font-size:32px;font-weight:600;letter-spacing:-.01em;font-variant-numeric:tabular-nums;font-feature-settings:"tnum" 1}',
			'.stc-state{display:inline-flex;align-items:center;gap:6px;font-size:12px;color:var(--dsw-alias-label-secondary)}',
			'.stc-stateText{color:var(--dsw-alias-label-primary)}',
			'.stc-stateHint{font-variant-numeric:tabular-nums}',
			'.stc-dot{width:7px;height:7px;border-radius:50%;background:var(--dsw-alias-state-idle-primary);flex:none}',
			'.stc-dot[data-live="true"]{background:var(--dsw-alias-state-success-primary)}',
			'.stc-progress{display:flex;flex-direction:column;gap:6px}',
			'.stc-bar{position:relative;height:6px;border-radius:999px;background:var(--dsw-alias-bg-layer-2);overflow:hidden}',
			'.stc-fill{height:100%;border-radius:999px;background:var(--dsw-alias-brand-primary);transition:width .35s ease}',
			'.stc-fill[data-over="true"]{background:var(--dsw-alias-state-warn-primary)}',
			'.stc-root[data-task-clock="idle"] .stc-fill{background:var(--dsw-alias-state-idle-primary)}',
			'.stc-bar[data-indeterminate="true"] .stc-fill{width:38%;animation:stc-slide 1.7s ease-in-out infinite}',
			'@keyframes stc-slide{0%{transform:translateX(-115%)}55%{transform:translateX(180%)}100%{transform:translateX(270%)}}',
			'@media (prefers-reduced-motion:reduce){.stc-bar[data-indeterminate="true"] .stc-fill{animation:none;opacity:.5}}',
			'.stc-captionLine{display:flex;justify-content:space-between;gap:12px;font-size:12px;color:var(--dsw-alias-label-secondary)}',
			'.stc-captionText{min-width:0}',
			'.stc-percent{font-variant-numeric:tabular-nums;color:var(--dsw-alias-label-primary)}',
			'.stc-section{display:flex;flex-direction:column;gap:8px;border-top:1px solid var(--dsw-alias-border-l1);padding-top:12px}',
			'.stc-sectionTitle{font-size:11px;letter-spacing:.04em;text-transform:uppercase;color:var(--dsw-alias-label-secondary)}',
			'.stc-reading{display:flex;align-items:baseline;justify-content:space-between;gap:12px;font-size:12px;color:var(--dsw-alias-label-secondary)}',
			'.stc-readingValue{color:var(--dsw-alias-label-primary);font-variant-numeric:tabular-nums}',
			'.stc-readingHint{color:var(--dsw-alias-label-secondary)}',
			'.stc-agents{display:flex;flex-direction:column;gap:6px}',
			'.stc-agent{display:grid;grid-template-columns:auto minmax(0,1fr) auto;align-items:center;gap:8px;font-size:12px}',
			'.stc-agentName{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:var(--dsw-alias-label-primary)}',
			'.stc-agentMode{color:var(--dsw-alias-label-secondary);font-size:11px;margin-left:6px}',
			'.stc-agentTime{display:flex;flex-direction:column;align-items:flex-end;line-height:1.25}',
			'.stc-agentValue{font-variant-numeric:tabular-nums;color:var(--dsw-alias-label-primary)}',
			'.stc-agentState{color:var(--dsw-alias-label-secondary);font-size:11px}',
			'.stc-empty{font-size:12px;color:var(--dsw-alias-label-secondary)}',
			'.stc-foot{font-size:11px;color:var(--dsw-alias-label-secondary)}',
			'.stc-titleGlyph{flex:none}',
		].join('');

		/**
		 * Install this plugin's stylesheet for the plugin's lifetime.
		 * @returns {() => void} the cleanup.
		 */
		function insertStyles() {
			const style = document.createElement('style');
			style.setAttribute('data-dsh-plugin', TAB_ID);
			style.textContent = CSS;
			document.head.appendChild(style);
			return () => {
				style.remove();
			};
		}

		// ── the plugin ──────────────────────────────────────────────────────────
		/** Required browser services: the tab registry, the keyed seat, and copy. */
		const inject = ['slots', 'locale', 'sidebarRightTabs', 'sidebarRight', 'sessions'];

		/**
		 * Register the tab type, its guide card, its body, its chip, and its styles.
		 * @param {import('@deepseek-ai/cordis').Context} ctx - client root context.
		 */
		function apply(ctx) {
			const t = ctx.locale.bind(NS);
			const sessions = ctx.sessions;

			const definition = {
				id: TAB_ID,
				kind: TAB_KIND,
				title: () => t('type.label'),
				guide: [{
					id: 'session-task-clock',
					order: 30,
					title: () => t('guide.title'),
					description: () => t('guide.description'),
					icon: ClockGlyph,
				}],
			};

			ctx.effect(() => ctx.locale.register(NS, { en, es }), 'session-task-clock: dictionaries');
			ctx.effect(() => ctx.sidebarRightTabs.register(definition), 'session-task-clock: tab type');
			ctx.effect(() => insertStyles(), 'session-task-clock: styles');
			ctx.effect(() => ctx.slots.inject('sidebar.right.pane.tab', () => ctx.slots.register({
				name: 'sidebar.right.pane.tab',
				key: TAB_ID,
				locale: NS,
				inject: () => ({
					/**
					 * Best-effort read of one child's own timing projection, through a
					 * binding that already exists. Never forces history open.
					 * @param {string} childId - the child Session id.
					 * @returns {object | undefined} the `subagentTiming` view.
					 */
					readAgentTiming: (childId) => {
						try {
							const binding = sessions.binding(childId);
							if (binding === undefined || binding === null) return undefined;
							const face = binding.session.projections.faceOf(CHILD_TIMING_KEY);
							return face.getSnapshot();
						} catch (error) {
							return undefined;
						}
					},
				}),
			}, TaskClockBody)), 'session-task-clock: tab body');
			ctx.effect(() => ctx.slots.inject('sidebar.right.pane.tab.title', () => ctx.slots.register({
				name: 'sidebar.right.pane.tab.title',
				key: TAB_ID,
			}, TaskClockTitle)), 'session-task-clock: tab title');
		}

		return { inject, apply };
	},
});
