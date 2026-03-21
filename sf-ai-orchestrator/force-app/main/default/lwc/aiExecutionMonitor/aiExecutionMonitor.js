import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getExecutions    from '@salesforce/apex/AIExecutionMonitorController.getExecutions';
import getStepExecutions from '@salesforce/apex/AIExecutionMonitorController.getStepExecutions';

const COLUMNS = [
    { label: 'Name',        fieldName: 'Name',            type: 'text'    },
    { label: 'Workflow',    fieldName: 'workflowName',    type: 'text'    },
    { label: 'Status',      fieldName: 'Status__c',       type: 'text'    },
    { label: 'Started',     fieldName: 'Started_At__c',   type: 'date',
      typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit',
                        hour: '2-digit', minute: '2-digit' } },
    { label: 'Duration (s)', fieldName: 'Duration_Seconds__c', type: 'number' },
    { label: 'Tokens',      fieldName: 'Total_Tokens_Used__c', type: 'number' },
    { label: 'Triggered By', fieldName: 'initiatedBy',   type: 'text'    },
    { type: 'action', typeAttributes: {
        rowActions: [{ label: 'View Detail', name: 'view_detail' }]
    }}
];

const STEP_COLUMNS = [
    { label: 'Step',        fieldName: 'stepName',        type: 'text'    },
    { label: 'Status',      fieldName: 'Status__c',       type: 'text'    },
    { label: 'Provider',    fieldName: 'Provider_Used__c', type: 'text'   },
    { label: 'Model',       fieldName: 'Model_Used__c',   type: 'text'    },
    { label: 'Tokens',      fieldName: 'Tokens_Used__c',  type: 'number'  },
    { label: 'Duration (ms)', fieldName: 'Duration_Ms__c', type: 'number' },
    { label: 'Error',       fieldName: 'Error_Message__c', type: 'text'   }
];

const STATUS_OPTIONS = [
    { label: 'All',        value: '' },
    { label: 'Pending',    value: 'PENDING' },
    { label: 'Running',    value: 'RUNNING' },
    { label: 'Completed',  value: 'COMPLETED' },
    { label: 'Failed',     value: 'FAILED' },
    { label: 'Retrying',   value: 'RETRYING' },
    { label: 'Cancelled',  value: 'CANCELLED' }
];

export default class AiExecutionMonitor extends LightningElement {
    @track executions       = [];
    @track isLoading        = false;
    @track error            = null;
    @track statusFilter     = '';
    @track searchTerm       = '';
    @track showDetail       = false;
    @track selectedExecution = null;
    @track selectedStepExecutions = [];

    columns      = COLUMNS;
    stepColumns  = STEP_COLUMNS;
    statusOptions = STATUS_OPTIONS;

    connectedCallback() {
        this.loadExecutions();
    }

    async loadExecutions() {
        this.isLoading = true;
        this.error     = null;
        try {
            const data = await getExecutions({
                statusFilter: this.statusFilter,
                searchTerm:   this.searchTerm
            });
            // Flatten lookup fields for datatable
            this.executions = data.map(e => ({
                ...e,
                workflowName: e.AI_Workflow__r?.Name  ?? '',
                initiatedBy:  e.Initiated_By__r?.Name ?? ''
            }));
        } catch (err) {
            this.error = err.body?.message ?? 'Failed to load executions';
        } finally {
            this.isLoading = false;
        }
    }

    handleStatusFilter(event) {
        this.statusFilter = event.detail.value;
        this.loadExecutions();
    }

    handleSearch(event) {
        this.searchTerm = event.detail.value;
        this.loadExecutions();
    }

    handleRefresh() {
        this.loadExecutions();
    }

    async handleRowAction(event) {
        const action = event.detail.action;
        const row    = event.detail.row;

        if (action.name === 'view_detail') {
            this.selectedExecution = row;
            this.showDetail        = true;
            await this.loadStepExecutions(row.Id);
        }
    }

    async loadStepExecutions(executionId) {
        try {
            const steps = await getStepExecutions({ executionId });
            this.selectedStepExecutions = steps.map(s => ({
                ...s,
                stepName: s.AI_Step__c ?? ''
            }));
        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({
                title:   'Error',
                message: err.body?.message ?? 'Failed to load step details',
                variant: 'error'
            }));
        }
    }

    closeDetail() {
        this.showDetail             = false;
        this.selectedExecution      = null;
        this.selectedStepExecutions = [];
    }

    get isEmpty() {
        return !this.isLoading && this.executions.length === 0;
    }
}
