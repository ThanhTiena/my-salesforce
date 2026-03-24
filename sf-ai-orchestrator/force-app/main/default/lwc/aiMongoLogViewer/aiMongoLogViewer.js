import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import queryMongoLogs from '@salesforce/apex/AIExecutionMonitorController.queryMongoLogs';

const STATUS_OPTIONS = [
    { label: 'All Statuses',  value: 'ALL'       },
    { label: 'Completed',     value: 'COMPLETED'  },
    { label: 'Failed',        value: 'FAILED'     },
    { label: 'Running',       value: 'RUNNING'    },
    { label: 'Retrying',      value: 'RETRYING'   },
    { label: 'Pending',       value: 'PENDING'    },
];

const PERIOD_OPTIONS = [
    { label: 'All time',     value: '0'   },
    { label: 'Last 24 h',   value: '1'   },
    { label: 'Last 7 days', value: '7'   },
    { label: 'Last 30 days',value: '30'  },
    { label: 'Last 90 days',value: '90'  },
];

const PAGE_SIZE_OPTIONS = [
    { label: '10 / page', value: '10' },
    { label: '25 / page', value: '25' },
    { label: '50 / page', value: '50' },
    { label: '100 / page',value: '100'},
];

const SORT_FIELDS = {
    workflowName   : 'workflow_name',
    startedAt      : 'started_at',
    durationSeconds: 'duration_seconds',
    totalTokensUsed: 'total_tokens_used',
    status         : 'status',
};

const STATUS_CLASS = {
    COMPLETED : 'slds-badge slds-theme_success log-badge',
    FAILED    : 'slds-badge slds-theme_error   log-badge',
    RUNNING   : 'slds-badge slds-theme_info    log-badge log-badge--pulse',
    RETRYING  : 'slds-badge slds-theme_warning log-badge log-badge--pulse',
    PENDING   : 'slds-badge                    log-badge',
};

const STEP_STATUS_CLASS = {
    COMPLETED : 'step-dot step-dot--success',
    FAILED    : 'step-dot step-dot--error',
    RUNNING   : 'step-dot step-dot--running',
    RETRYING  : 'step-dot step-dot--warning',
    PENDING   : 'step-dot step-dot--neutral',
};

export default class AiMongoLogViewer extends LightningElement {

    // ─── Filter state ────────────────────────────────────────────────────────
    @track searchText    = '';
    @track statusFilter  = 'ALL';
    @track daysBack      = '7';
    @track sortField     = 'startedAt';
    @track sortAsc       = false;
    @track pageNumber    = 1;
    @track pageSize      = '25';

    // ─── Data state ──────────────────────────────────────────────────────────
    @track rows          = [];
    @track totalCount    = 0;
    @track isLoading     = false;

    // ─── Detail drawer ───────────────────────────────────────────────────────
    @track selectedRow   = null;   // full row with steps
    @track activeStep    = null;   // step selected inside drawer
    @track drawerTab     = 'overview';  // overview | steps | raw

    // ─── Search debounce ─────────────────────────────────────────────────────
    _searchTimer = null;

    // ─── Options ─────────────────────────────────────────────────────────────
    get statusOptions()   { return STATUS_OPTIONS;    }
    get periodOptions()   { return PERIOD_OPTIONS;    }
    get pageSizeOptions() { return PAGE_SIZE_OPTIONS; }

    // ─── Lifecycle ────────────────────────────────────────────────────────────
    connectedCallback() {
        this._load();
    }

    // ─── Computed ─────────────────────────────────────────────────────────────

    get hasRows()        { return this.rows.length > 0; }
    get showDrawer()     { return !!this.selectedRow; }
    get totalPages()     { return Math.max(1, Math.ceil(this.totalCount / parseInt(this.pageSize, 10))); }
    get isFirstPage()    { return this.pageNumber <= 1; }
    get isLastPage()     { return this.pageNumber >= this.totalPages; }
    get paginationLabel(){
        const ps   = parseInt(this.pageSize, 10);
        const from = (this.pageNumber - 1) * ps + 1;
        const to   = Math.min(this.pageNumber * ps, this.totalCount);
        return this.totalCount > 0
            ? `${from}–${to} of ${this.totalCount}`
            : '0 results';
    }

    get drawerTabOverview() { return this.drawerTab === 'overview'; }
    get drawerTabSteps()    { return this.drawerTab === 'steps'; }
    get drawerTabRaw()      { return this.drawerTab === 'raw'; }

    get drawerTabOverviewClass() { return 'drawer-tab' + (this.drawerTab === 'overview' ? ' drawer-tab--active' : ''); }
    get drawerTabStepsClass()    { return 'drawer-tab' + (this.drawerTab === 'steps'    ? ' drawer-tab--active' : ''); }
    get drawerTabRawClass()      { return 'drawer-tab' + (this.drawerTab === 'raw'      ? ' drawer-tab--active' : ''); }

    get selectedRowJson() {
        if (!this.selectedRow) return '';
        try {
            return JSON.stringify(this.selectedRow, null, 2);
        } catch (e) {
            return String(this.selectedRow);
        }
    }

    get activeStepJson() {
        if (!this.activeStep) return '';
        try {
            return JSON.stringify(this.activeStep, null, 2);
        } catch (e) {
            return '';
        }
    }

    get stepCount() {
        return this.selectedRow?.steps?.length ?? 0;
    }

    // Sort indicator helpers — one getter per column
    get sortIconWorkflow()  { return this._sortIcon('workflowName');    }
    get sortIconStarted()   { return this._sortIcon('startedAt');       }
    get sortIconDuration()  { return this._sortIcon('durationSeconds'); }
    get sortIconTokens()    { return this._sortIcon('totalTokensUsed'); }
    get sortIconStatus()    { return this._sortIcon('status');          }

    _sortIcon(field) {
        if (this.sortField !== field) return 'utility:arrowup';
        return this.sortAsc ? 'utility:arrowup' : 'utility:arrowdown';
    }

    get sortClassWorkflow()  { return this._sortClass('workflowName');    }
    get sortClassStarted()   { return this._sortClass('startedAt');       }
    get sortClassDuration()  { return this._sortClass('durationSeconds'); }
    get sortClassTokens()    { return this._sortClass('totalTokensUsed'); }
    get sortClassStatus()    { return this._sortClass('status');          }

    _sortClass(field) {
        return 'col-header' + (this.sortField === field ? ' col-header--active' : '');
    }

    // ─── Data loading ─────────────────────────────────────────────────────────

    async _load() {
        this.isLoading = true;
        try {
            const days = parseInt(this.daysBack, 10);
            const result = await queryMongoLogs({
                searchText  : this.searchText.trim() || null,
                statusFilter: this.statusFilter === 'ALL' ? null : this.statusFilter,
                daysBack    : days > 0 ? days : null,
                sortField   : SORT_FIELDS[this.sortField] ?? 'started_at',
                sortAsc     : this.sortAsc,
                pageNumber  : this.pageNumber,
                pageSize    : parseInt(this.pageSize, 10),
            });

            this.totalCount = result.totalCount ?? 0;
            this.rows = (result.rows ?? []).map(r => this._mapRow(r));

            // Refresh selected row if drawer is open
            if (this.selectedRow) {
                const fresh = this.rows.find(r => r.sfExecutionId === this.selectedRow.sfExecutionId);
                if (fresh) this.selectedRow = fresh;
            }
        } catch (e) {
            this._toast('Load Error', e.body?.message ?? e.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    _mapRow(r) {
        const startMs = r.startedAtEpochMs;
        const endMs   = r.completedAtEpochMs;
        return {
            ...r,
            statusClass      : STATUS_CLASS[r.status] ?? STATUS_CLASS.PENDING,
            startedAtDisplay : startMs ? new Date(startMs).toLocaleString() : '—',
            completedAtDisplay: endMs  ? new Date(endMs).toLocaleString()   : '—',
            durationDisplay  : r.durationSeconds != null
                ? (r.durationSeconds < 1
                    ? (r.durationSeconds * 1000).toFixed(0) + 'ms'
                    : r.durationSeconds.toFixed(1) + 's')
                : '—',
            tokensDisplay    : r.totalTokensUsed
                ? (r.totalTokensUsed >= 1000 ? (r.totalTokensUsed / 1000).toFixed(1) + 'k' : String(r.totalTokensUsed))
                : '0',
            hasError         : !!r.errorMessage,
            steps            : (r.steps ?? []).map((s, i) => this._mapStep(s, i)),
        };
    }

    _mapStep(s, idx) {
        return {
            ...s,
            dotClass         : STEP_STATUS_CLASS[s.status] ?? STEP_STATUS_CLASS.PENDING,
            durationDisplay  : s.durationMs != null
                ? (s.durationMs < 1000 ? s.durationMs + 'ms' : (s.durationMs / 1000).toFixed(1) + 's')
                : '—',
            tokensDisplay    : s.tokensUsed ? String(s.tokensUsed) : '0',
            hasPrompt        : !!s.promptSent,
            hasOutput        : !!s.parsedOutput,
            hasRaw           : !!s.rawResponse,
            hasError         : !!s.errorMessage,
            rowKey           : (s.sfStepExecutionId || String(idx)),
        };
    }

    // ─── Filter handlers ──────────────────────────────────────────────────────

    handleSearchChange(event) {
        this.searchText = event.detail.value;
        clearTimeout(this._searchTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._searchTimer = setTimeout(() => {
            this.pageNumber = 1;
            this._load();
        }, 400);
    }

    handleStatusChange(event) {
        this.statusFilter = event.detail.value;
        this.pageNumber   = 1;
        this._load();
    }

    handlePeriodChange(event) {
        this.daysBack   = event.detail.value;
        this.pageNumber = 1;
        this._load();
    }

    handlePageSizeChange(event) {
        this.pageSize   = event.detail.value;
        this.pageNumber = 1;
        this._load();
    }

    handleRefresh() {
        this._load();
    }

    handleClearFilters() {
        this.searchText   = '';
        this.statusFilter = 'ALL';
        this.daysBack     = '7';
        this.pageNumber   = 1;
        this._load();
    }

    // ─── Sort ─────────────────────────────────────────────────────────────────

    handleSort(event) {
        const field = event.currentTarget.dataset.field;
        if (this.sortField === field) {
            this.sortAsc = !this.sortAsc;
        } else {
            this.sortField = field;
            this.sortAsc   = false;
        }
        this.pageNumber = 1;
        this._load();
    }

    // ─── Pagination ───────────────────────────────────────────────────────────

    handlePrevPage() {
        if (!this.isFirstPage) {
            this.pageNumber -= 1;
            this._load();
        }
    }

    handleNextPage() {
        if (!this.isLastPage) {
            this.pageNumber += 1;
            this._load();
        }
    }

    handleFirstPage() {
        if (!this.isFirstPage) {
            this.pageNumber = 1;
            this._load();
        }
    }

    handleLastPage() {
        if (!this.isLastPage) {
            this.pageNumber = this.totalPages;
            this._load();
        }
    }

    // ─── Row detail drawer ────────────────────────────────────────────────────

    handleRowClick(event) {
        const execId = event.currentTarget.dataset.id;
        if (this.selectedRow?.sfExecutionId === execId) {
            this.selectedRow = null;
            this.activeStep  = null;
        } else {
            this.selectedRow = this.rows.find(r => r.sfExecutionId === execId) ?? null;
            this.activeStep  = null;
            this.drawerTab   = 'overview';
        }
    }

    handleCloseDrawer() {
        this.selectedRow = null;
        this.activeStep  = null;
    }

    handleDrawerTab(event) {
        this.drawerTab = event.currentTarget.dataset.tab;
        this.activeStep = null;
    }

    handleStepClick(event) {
        const stepId   = event.currentTarget.dataset.stepId;
        const isSame   = this.activeStep?.rowKey === stepId;
        const newActive = isSame ? null : (this.selectedRow?.steps?.find(s => s.rowKey === stepId) ?? null);
        this._setActiveStep(newActive);
    }

    handleCloseStepDetail() {
        this._setActiveStep(null);
    }

    _setActiveStep(step) {
        this.activeStep = step;
        // Rebuild steps with isActiveStep flag so template can use if:true={s.isActiveStep}
        if (this.selectedRow) {
            const activeKey = step?.rowKey ?? null;
            this.selectedRow = {
                ...this.selectedRow,
                steps: this.selectedRow.steps.map(s => ({
                    ...s,
                    isActiveStep: s.rowKey === activeKey,
                })),
            };
        }
    }

    // ─── Copy to clipboard ────────────────────────────────────────────────────

    handleCopyExecId(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this._copyToClipboard(id, 'Execution ID copied');
    }

    handleCopyJson() {
        this._copyToClipboard(this.selectedRowJson, 'Raw JSON copied');
    }

    handleCopyStepJson() {
        this._copyToClipboard(this.activeStepJson, 'Step JSON copied');
    }

    _copyToClipboard(text, successMsg) {
        try {
            navigator.clipboard.writeText(text).then(() => {
                this._toast('Copied', successMsg, 'success');
            }).catch(() => {
                this._toast('Copy Failed', 'Could not access clipboard', 'warning');
            });
        } catch (e) {
            this._toast('Copy Failed', 'Clipboard API not available', 'warning');
        }
    }

    // ─── Export CSV ───────────────────────────────────────────────────────────

    handleExportCsv() {
        if (!this.rows.length) return;
        const headers = ['Execution ID','Workflow','Version','Status','Initiated By',
                         'Started At','Completed At','Duration','Tokens','Retries',
                         'Trigger Object','Trigger Record','Error'];
        const lines = this.rows.map(r => [
            r.sfExecutionId, r.workflowName, r.workflowVersion, r.status,
            r.initiatedBy, r.startedAtDisplay, r.completedAtDisplay,
            r.durationDisplay, r.tokensDisplay, r.retryCount,
            r.triggerObject, r.triggerRecordId,
            (r.errorMessage || '').replace(/"/g, '""'),
        ].map(v => '"' + (v ?? '') + '"').join(','));

        const csv  = [headers.join(','), ...lines].join('\n');
        const blob = new Blob([csv], { type: 'text/csv' });
        const url  = URL.createObjectURL(blob);
        const a    = document.createElement('a');
        a.href     = url;
        a.download = 'mongo_execution_logs_' + new Date().toISOString().slice(0, 10) + '.csv';
        a.click();
        URL.revokeObjectURL(url);
        this._toast('Exported', lines.length + ' rows exported as CSV', 'success');
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: message ?? '', variant }));
    }
}
