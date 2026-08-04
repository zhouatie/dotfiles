import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import test from "node:test";
import kittyTabStatus from "../extensions/kitty-tab-status.ts";

type Handler = (event: any, ctx: any) => unknown;

class TestEventBus {
	private readonly handlers = new Map<string, Array<(data: unknown) => void>>();

	on(channel: string, handler: (data: unknown) => void): () => void {
		const handlers = this.handlers.get(channel) ?? [];
		handlers.push(handler);
		this.handlers.set(channel, handlers);
		return () => {
			this.handlers.set(
				channel,
				handlers.filter((candidate) => candidate !== handler),
			);
		};
	}

	emit(channel: string, data: unknown): void {
		for (const handler of this.handlers.get(channel) ?? []) {
			handler(data);
		}
	}
}

function createHarness() {
	const handlers = new Map<string, Handler[]>();
	const events = new TestEventBus();
	const titles: string[] = [];
	let sessionName = "kitty-sync";
	const ctx = {
		cwd: process.cwd(),
		ui: {
			setTitle(title: string) {
				titles.push(title);
			},
		},
	};
	const pi = {
		events,
		getSessionName: () => sessionName,
		on(event: string, handler: Handler) {
			const registered = handlers.get(event) ?? [];
			registered.push(handler);
			handlers.set(event, registered);
		},
	};

	kittyTabStatus(pi as never);

	return {
		ctx,
		events,
		titles,
		setSessionName(name: string) {
			sessionName = name;
		},
		async run(event: string, payload: unknown = {}) {
			for (const handler of handlers.get(event) ?? []) {
				await handler(payload, ctx);
			}
		},
	};
}

const cwdNamePattern = basename(process.cwd()).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const ACTIVE_TITLE_PATTERN = new RegExp(
	`^[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏] (Thinking|Working) \\| π - kitty-sync - ${cwdNamePattern}$`,
);

test("maps the complete Pi lifecycle onto Kitty tab states", async () => {
	const harness = createHarness();
	const { events, titles, run } = harness;
	const baseTitle = `π - kitty-sync - ${basename(process.cwd())}`;
	let shutDown = false;

	try {
		await run("session_start");
		assert.equal(titles.at(-1), baseTitle);

		await run("agent_start");
		assert.match(titles.at(-1) ?? "", ACTIVE_TITLE_PATTERN);
		assert.match(titles.at(-1) ?? "", / Thinking \| /);

		await run("tool_execution_start", { toolCallId: "tool-1" });
		await run("tool_execution_start", { toolCallId: "tool-2" });
		assert.match(titles.at(-1) ?? "", / Working \| /);

		events.emit("permissions:ui_prompt", {
			requestId: "request-1",
			source: "tool_call",
			surface: "bash",
			value: "git push",
			message: "Allow git push?",
		});
		assert.equal(titles.at(-1), `Action required | ${baseTitle}`);

		// Automatic decisions can happen on sibling gates and must not dismiss
		// the user-facing permission state.
		events.emit("permissions:decision", {
			result: "allow",
			resolution: "policy_allow",
		});
		assert.equal(titles.at(-1), `Action required | ${baseTitle}`);

		events.emit("permissions:decision", {
			result: "allow",
			resolution: "user_approved",
		});
		assert.match(titles.at(-1) ?? "", / Working \| /);

		await run("tool_execution_end", { toolCallId: "tool-1" });
		assert.match(titles.at(-1) ?? "", / Working \| /);

		await run("tool_execution_end", { toolCallId: "tool-2" });
		assert.match(titles.at(-1) ?? "", / Thinking \| /);

		await run("agent_settled");
		assert.equal(titles.at(-1), `Ready | ${baseTitle}`);

		harness.setSessionName("renamed");
		await run("session_info_changed", { name: "renamed" });
		assert.equal(
			titles.at(-1),
			`Ready | π - renamed - ${basename(process.cwd())}`,
		);

		await run("session_shutdown");
		shutDown = true;
		assert.equal(titles.at(-1), `π - renamed - ${basename(process.cwd())}`);
	} finally {
		if (!shutDown) await run("session_shutdown");
	}
});

test("restores idle after a permission prompt shown before an agent run", async () => {
	const harness = createHarness();
	const baseTitle = `π - kitty-sync - ${basename(process.cwd())}`;

	try {
		await harness.run("session_start");
		harness.events.emit("permissions:ui_prompt", {
			value: "outside-path",
			message: "Allow external directory access?",
		});
		assert.equal(harness.titles.at(-1), `Action required | ${baseTitle}`);

		harness.events.emit("permissions:decision", {
			result: "deny",
			resolution: "user_denied",
		});
		assert.equal(harness.titles.at(-1), baseTitle);
	} finally {
		await harness.run("session_shutdown");
	}
});

test("uses the status markers configured by the current Kitty tab bar", () => {
	const kittyRules = readFileSync(join(homedir(), ".config/kitty/tab_bar.py"), "utf8");
	for (const marker of ["action required", "thinking", "working", "ready"]) {
		assert.match(kittyRules.toLowerCase(), new RegExp(`['\"]${marker}['\"]`));
	}
});
