import type {
	IWorkflowBase,
	IWorkflowExecuteHooks,
	IWorkflowHooksOptionalParameters,
	WorkflowExecuteMode,
} from './Interfaces';

export class WorkflowHooks {
	mode: WorkflowExecuteMode;

	workflowData: IWorkflowBase;

	executionId: string;

	pushRef?: string;

	retryOf?: string;

	hookFunctions: IWorkflowExecuteHooks;

	constructor(
		hookFunctions: IWorkflowExecuteHooks,
		mode: WorkflowExecuteMode,
		executionId: string,
		workflowData: IWorkflowBase,
		optionalParameters?: IWorkflowHooksOptionalParameters,
	) {
		// eslint-disable-next-line @typescript-eslint/prefer-nullish-coalescing
		optionalParameters = optionalParameters || {};

		this.hookFunctions = hookFunctions;
		this.mode = mode;
		this.executionId = executionId;
		this.workflowData = workflowData;
		this.pushRef = optionalParameters.pushRef;
		// retryOf might be `null` from TypeORM
		this.retryOf = optionalParameters.retryOf ?? undefined;
	}

	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	async executeHookFunctions(hookName: string, parameters: any[]) {
		const hooks = this.hookFunctions[hookName];
		if (hooks !== undefined && Array.isArray(hooks)) {
			for (const hookFunction of hooks) {
				await hookFunction.apply(this, parameters);
			}
		}
	}
}
