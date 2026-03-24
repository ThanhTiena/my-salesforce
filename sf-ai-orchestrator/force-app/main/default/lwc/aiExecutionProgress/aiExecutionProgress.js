import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getExecutionProgress from '@salesforce/apex/AIExecutionMonitorController.getExecutionProgress';

const POLL_INTERVAL_MS = 2500;

const TERMINAL_STATUSES = new Set(['COMPLETED', 'FAILED', 'CANCELLED']);

const NODE_META = {
    START        : { icon: '▶', label: 'Start'        },
    END          : { icon: '⏹', label: 'End'          },
    AI_INFERENCE : { icon: '🤖', label: 'AI Inference' },
    DECISION     : { icon: '◆',  label: 'Decision'     },
    HTTP_CALLOUT : { icon: '🌐', label: 'HTTP Callout' },
    APEX_ACTION  : { icon: '⚡', label: 'Apex Action'  },
    FLOW_LAUNCH  : { icon: '🔀', label: 'Launch Flow'  },
    WAIT         : { icon: '⏳', label: 'Wait'         },
    LOOP         : { icon: '🔁', label: 'Loop'         },
    SUBFLOW      : { icon: '📦', label: 'Sub-Workflow' },
    NOTIFICATION : { icon: '🔔', label: 'Notification' },
};

const STATUS_BADGE = {
    COMPLETED : 'status-badge status-badge--success',
    FAILED    : 'status-badge status-badge--error',
    RUNNING   : 'status-badge status-badge--running',
    RETRYING  : 'status-badge status-badge--warning',
    PENDING   : 'status-badge status-badge--neutral',
};

export default class AiExecutionProgress extends LightningElement {

    @track execution  = {};
    @track steps      = [];
    @track isLoading  = true;
    @track selectedStep = null;
    @track showRaw    = false;

    _pollTimer = null;

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        if (this.executionId) {
            this._load();
        }
    }

    disconnectedCallback() {
        this._stopPolling();
    }

    // When executionId is set from outside (e.g. after Run Now)
    @api
    get executionId() { return this._executionId; }
    set executionId(val) {
        this._executionId = val;
        this._stopPolling();
        this.execution   = {};
        this.steps       = [];
        this.selectedStep = null;
        if (val) this._load();
    }

    // ─── Data ─────────────────────────────────────────────────────────────────

    async _load() {
        this.isLoading = true;
        try {
            const data = await getExecutionProgress({ executionId: this._executionId });
            this._applyData(data);

            // Keep polling while execution is still live
            if (!TERMINAL_STATUSES.has(data.status)) {
                this._startPolling();
            } else {
                this._stopPolling();
            }
        } catch (e) {
            this._showToast('Load Error', e.body?.message ?? e.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    _applyData(data) {
        this.execution = data;
        this.steps = (data.steps || []).map((s, idx) => {
            const meta = NODE_META[s.stepType] || { icon: '●', label: s.stepType };
            return {
                ...s,
                icon           : meta.icon,
                nodeClass      : this._nodeClass(s),
                ringClass      : this._ringClass(s.status),
                connectorClass : this._connectorClass(s.status, idx),
                showConnector  : idx > 0,
                statusBadgeClass : STATUS_BADGE[s.status] || STATUS_BADGE.PENDING,
                durationDisplay : s.durationMs != null ? (s.durationMs < 1000 ? s.durationMs + 'ms' : (s.durationMs / 1000).toFixed(1) + 's') : null,
            };
        });

        // Refresh selected step if drawer is open
        if (this.selectedStep) {
            const refreshed = this.steps.find(s => s.stepId === this.selectedStep.stepId);
            if (refreshed) this.selectedStep = refreshed;
        }
    }

    _startPolling() {
        if (this._pollTimer) return;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._pollTimer = setInterval(async () => {
            try {
                const data = await getExecutionProgress({ executionId: this._executionId });
                this._applyData(data);
                if (TERMINAL_STATUSES.has(data.status)) {
                    this._stopPolling();
                }
            } catch (e) {
                this._stopPolling();
            }
        }, POLL_INTERVAL_MS);
    }

    _stopPolling() {
        if (this._pollTimer) {
            clearInterval(this._pollTimer);
            this._pollTimer = null;
        }
    }

    // ─── View model helpers ───────────────────────────────────────────────────

    _nodeClass(step) {
        const type   = (step.stepType || '').toLowerCase().replace(/_/g, '-');
        const status = (step.status || 'pending').toLowerCase();
        return `pipeline-node pipeline-node--${type} pipeline-node--${status}`;
    }

    _ringClass(status) {
        const s = (status || 'PENDING').toUpperCase();
        if (s === 'RUNNING')   return 'ring ring--spinning';
        if (s === 'COMPLETED') return 'ring ring--done';
        if (s === 'FAILED')    return 'ring ring--failed';
        if (s === 'RETRYING')  return 'ring ring--retrying';
        return 'ring ring--pending';
    }

    _connectorClass(status, idx) {
        if (idx === 0) return '';
        const prevStatus = this.steps[idx - 1]?.status || 'PENDING';
        const lit = prevStatus === 'COMPLETED';
        return 'connector' + (lit ? ' connector--lit' : '');
    }

    // ─── Getters ─────────────────────────────────────────────────────────────

    get workflowName()    { return this.execution?.workflowName ?? ''; }
    get isRunning()       { return this.execution?.status === 'RUNNING' || this.execution?.status === 'RETRYING'; }
    get statusBadgeClass(){ return STATUS_BADGE[this.execution?.status] || STATUS_BADGE.PENDING; }
    get rawLabel()        { return this.showRaw ? '▲ Hide raw response' : '▼ Show raw response'; }

    get durationDisplay() {
        const d = this.execution?.durationSeconds;
        if (d == null) return null;
        return d < 1 ? (d * 1000).toFixed(0) + 'ms' : d.toFixed(1) + 's';
    }

    get tokenDisplay() {
        const t = this.execution?.totalTokens;
        if (!t) return null;
        return t >= 1000 ? (t / 1000).toFixed(1) + 'k tokens' : t + ' tokens';
    }

    // ─── Handlers ─────────────────────────────────────────────────────────────

    handleRefresh() {
        this._load();
    }

    handleClose() {
        this._stopPolling();
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleStepClick(event) {
        const stepId = event.currentTarget.dataset.stepId;
        const step   = this.steps.find(s => s.stepId === stepId);
        if (!step) return;
        if (this.selectedStep?.stepId === stepId) {
            this.selectedStep = null; // toggle off
        } else {
            this.selectedStep = step;
            this.showRaw = false;
        }
    }

    handleCloseDrawer() {
        this.selectedStep = null;
    }

    handleToggleRaw() {
        this.showRaw = !this.showRaw;
    }

    // ─── Private ─────────────────────────────────────────────────────────────

    _executionId = null;

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
