import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getWorkflows  from '@salesforce/apex/WorkflowService.getWorkflows';
import runWorkflow   from '@salesforce/apex/WorkflowService.runWorkflow';

export default class AiWorkflowRunButton extends LightningElement {

    // Configurable via App Builder
    @api workflowIds = '';
    @api cardTitle   = 'AI Workflows';

    // Injected by the platform when placed on a record page
    @api recordId;

    @track workflows         = [];
    @track isLoading         = true;
    @track runningId         = null;   // which workflow row is currently being launched
    @track activeExecutionId = null;   // shows progress panel inline

    connectedCallback() {
        this._loadWorkflows();
    }

    async _loadWorkflows() {
        this.isLoading = true;
        try {
            const all = await getWorkflows();
            let active = (all ?? []).filter(w => w.Is_Active__c);

            // Filter to configured list if provided
            if (this.workflowIds?.trim()) {
                const ids = this.workflowIds.split(',').map(s => s.trim()).filter(Boolean);
                active = active.filter(w => ids.includes(w.Id));
            }

            this.workflows = active.map(w => ({
                id           : w.Id,
                name         : w.Name,
                triggerObject: w.Trigger_Object__c ?? '—',
                totalRuns    : w.Total_Executions__c ?? 0,
                lastRun      : w.Last_Executed__c
                    ? new Date(w.Last_Executed__c).toLocaleDateString() : 'Never',
            }));
        } catch (e) {
            this._toast('Load Error', e.body?.message ?? e.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get hasWorkflows()  { return this.workflows.length > 0; }
    get showProgress()  { return !!this.activeExecutionId; }

    isRunning(id) { return this.runningId === id; }

    async handleRun(event) {
        const workflowId = event.currentTarget.dataset.id;
        if (this.runningId) return;
        this.runningId = workflowId;
        try {
            const execId = await runWorkflow({
                workflowId     : workflowId,
                triggerRecordId: this.recordId ?? null,
            });
            this.activeExecutionId = execId;
            this._toast('Workflow Started', 'Execution queued.', 'success');
        } catch (e) {
            this._toast('Run Failed', e.body?.message ?? e.message, 'error');
        } finally {
            this.runningId = null;
        }
    }

    handleProgressClose() {
        this.activeExecutionId = null;
    }

    handleRefresh() {
        this._loadWorkflows();
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: message ?? '', variant }));
    }
}
