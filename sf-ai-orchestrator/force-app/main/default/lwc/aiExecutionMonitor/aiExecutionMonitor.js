import { LightningElement, track } from 'lwc';
import getDashboardMetrics   from '@salesforce/apex/AIExecutionMonitorController.getDashboardMetrics';
import getRecentExecutions   from '@salesforce/apex/AIExecutionMonitorController.getRecentExecutions';
import getTokenUsageByProvider from '@salesforce/apex/AIExecutionMonitorController.getTokenUsageByProvider';
import getStepExecutions     from '@salesforce/apex/AIExecutionMonitorController.getStepExecutions';

const STATUS_CLASSES = {
    COMPLETED : 'badge-success',
    FAILED    : 'badge-danger',
    RUNNING   : 'badge-info',
    RETRYING  : 'badge-warning',
    PENDING   : 'badge-neutral',
};

const PERIOD_OPTIONS = [
    { label: 'Last 24 hours', value: '1'  },
    { label: 'Last 7 days',   value: '7'  },
    { label: 'Last 30 days',  value: '30' },
];

export default class AiExecutionMonitor extends LightningElement {

    @track metrics      = {};
    @track executions   = [];
    @track tokenUsage   = [];
    @track stepExecutions = [];
    @track isLoading    = false;
    @track showStepModal = false;

    daysBack = '7';

    get periodOptions() { return PERIOD_OPTIONS; }

    connectedCallback() {
        this._loadAll();
    }

    // ─── Data Loading ────────────────────────────────────────────────────────

    async _loadAll() {
        this.isLoading = true;
        try {
            const days = parseInt(this.daysBack, 10);
            const [metrics, executions, tokenUsage] = await Promise.all([
                getDashboardMetrics({ daysBack: days }),
                getRecentExecutions({ limitRows: 25 }),
                getTokenUsageByProvider({ daysBack: days }),
            ]);

            this.metrics    = metrics ?? {};
            this.tokenUsage = tokenUsage ?? [];
            this.executions = (executions ?? []).map(ex => ({
                ...ex,
                statusClass     : STATUS_CLASSES[ex.status] ?? 'badge-neutral',
                startedAtDisplay: ex.startedAt ? new Date(ex.startedAt).toLocaleString() : '—',
                durationDisplay : ex.durationSeconds != null
                    ? ex.durationSeconds.toFixed(1) + 's' : '—',
            }));
        } catch (e) {
            console.error('Monitor load error:', e);
        } finally {
            this.isLoading = false;
        }
    }

    // ─── Getters ─────────────────────────────────────────────────────────────

    get hasExecutions()  { return this.executions.length > 0; }
    get hasTokenData()   { return this.tokenUsage.length > 0; }
    get hasStepData()    { return this.stepExecutions.length > 0; }

    get successRateDisplay() {
        if (!this.metrics.successRate && this.metrics.successRate !== 0) return '—';
        return this.metrics.successRate.toFixed(1) + '%';
    }

    get totalTokensDisplay() {
        const t = this.metrics.totalTokensUsed;
        if (!t) return '0';
        return t >= 1000 ? (t / 1000).toFixed(1) + 'k' : String(t);
    }

    // ─── Handlers ─────────────────────────────────────────────────────────────

    handlePeriodChange(event) {
        this.daysBack = event.detail.value;
        this._loadAll();
    }

    handleRefresh() {
        this._loadAll();
    }

    async handleViewSteps(event) {
        const execId = event.currentTarget.dataset.id;
        this.showStepModal = true;
        try {
            this.stepExecutions = await getStepExecutions({ executionId: execId });
        } catch (e) {
            console.error('Failed to load steps:', e);
        }
    }

    handleCloseModal() {
        this.showStepModal   = false;
        this.stepExecutions  = [];
    }
}
