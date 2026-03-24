import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDashboardMetrics   from '@salesforce/apex/AIExecutionMonitorController.getDashboardMetrics';
import getRecentExecutions   from '@salesforce/apex/AIExecutionMonitorController.getRecentExecutions';
import getWorkflows          from '@salesforce/apex/WorkflowService.getWorkflows';
import runWorkflow           from '@salesforce/apex/WorkflowService.runWorkflow';

const STATUS_CLASS = {
    COMPLETED : 'slds-badge slds-theme_success home-badge',
    FAILED    : 'slds-badge slds-theme_error home-badge',
    RUNNING   : 'slds-badge slds-theme_info home-badge',
    RETRYING  : 'slds-badge slds-theme_warning home-badge',
    PENDING   : 'slds-badge home-badge',
    CANCELLED : 'slds-badge home-badge',
};

export default class AiOrchestratorHome extends LightningElement {

    @track metrics        = {};
    @track recentRuns     = [];
    @track workflows      = [];
    @track isLoading      = true;
    @track showRunModal   = false;
    @track selectedWorkflowId = null;
    @track triggerRecordId    = '';
    @track isRunning          = false;
    @track activeExecutionId  = null;

    connectedCallback() {
        this._load();
    }

    async _load() {
        this.isLoading = true;
        try {
            const [metrics, runs, workflows] = await Promise.all([
                getDashboardMetrics({ daysBack: 7 }),
                getRecentExecutions({ limitRows: 10 }),
                getWorkflows(),
            ]);
            this.metrics  = metrics ?? {};
            this.workflows = (workflows ?? []).map(w => ({
                label : w.Name + (w.Is_Active__c ? ' (Active)' : ''),
                value : w.Id,
                isActive: w.Is_Active__c,
                triggerObject: w.Trigger_Object__c,
                totalRuns: w.Total_Executions__c ?? 0,
                lastRun: w.Last_Executed__c
                    ? new Date(w.Last_Executed__c).toLocaleDateString() : 'Never',
            }));
            this.recentRuns = (runs ?? []).map(r => ({
                ...r,
                statusClass: STATUS_CLASS[r.status] ?? STATUS_CLASS.PENDING,
                startedAtDisplay: r.startedAt
                    ? new Date(r.startedAt).toLocaleString() : '—',
                durationDisplay: r.durationSeconds != null
                    ? (r.durationSeconds < 1 ? (r.durationSeconds * 1000).toFixed(0) + 'ms'
                        : r.durationSeconds.toFixed(1) + 's') : '—',
            }));
        } catch (e) {
            this._toast('Load Error', e.body?.message ?? e.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ── Getters ───────────────────────────────────────────────────────────────

    get successRateDisplay() {
        if (this.metrics.successRate == null) return '—';
        return this.metrics.successRate.toFixed(1) + '%';
    }
    get avgDurationDisplay() {
        const d = this.metrics.avgDurationSeconds;
        if (!d) return '—';
        return d < 1 ? (d * 1000).toFixed(0) + 'ms' : d.toFixed(1) + 's';
    }
    get totalTokensDisplay() {
        const t = this.metrics.totalTokensUsed;
        if (!t) return '0';
        return t >= 1000000 ? (t / 1000000).toFixed(1) + 'M'
             : t >= 1000    ? (t / 1000).toFixed(1) + 'k' : String(t);
    }
    get hasRecentRuns()  { return this.recentRuns.length > 0; }
    get hasWorkflows()   { return this.workflows.length > 0; }
    get activeWorkflows(){ return this.workflows.filter(w => w.isActive); }
    get isRunDisabled()  { return this.isRunning || !this.selectedWorkflowId; }

    // ── Run modal ─────────────────────────────────────────────────────────────

    handleOpenRunModal() {
        this.selectedWorkflowId = null;
        this.triggerRecordId    = '';
        this.showRunModal       = true;
    }
    handleCloseRunModal() {
        this.showRunModal = false;
    }
    handleWorkflowPick(event)   { this.selectedWorkflowId = event.detail.value; }
    handleRecordIdChange(event) { this.triggerRecordId    = event.detail.value; }

    async handleRunNow() {
        if (!this.selectedWorkflowId) return;
        this.isRunning = true;
        try {
            const execId = await runWorkflow({
                workflowId     : this.selectedWorkflowId,
                triggerRecordId: this.triggerRecordId || null,
            });
            this.showRunModal      = false;
            this.activeExecutionId = execId;
            this._toast('Workflow Started', 'Execution queued successfully.', 'success');
            this._load();
        } catch (e) {
            this._toast('Run Failed', e.body?.message ?? e.message, 'error');
        } finally {
            this.isRunning = false;
        }
    }

    handleProgressClose() {
        this.activeExecutionId = null;
    }

    handleViewExecution(event) {
        const execId = event.currentTarget.dataset.id;
        this.activeExecutionId = execId;
    }

    handleRefresh() {
        this._load();
    }

    // ── Private ───────────────────────────────────────────────────────────────

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: message ?? '', variant }));
    }
}
