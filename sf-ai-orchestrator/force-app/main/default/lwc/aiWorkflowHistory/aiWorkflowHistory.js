import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getVersionHistory from '@salesforce/apex/WorkflowService.getVersionHistory';
import restoreVersion    from '@salesforce/apex/WorkflowService.restoreVersion';

export default class AiWorkflowHistory extends LightningElement {

    @api workflowId;

    @track versions      = [];
    @track isLoading     = true;
    @track restoringId   = null;

    connectedCallback() {
        if (this.workflowId) this._load();
    }

    @api
    get workflowId() { return this._workflowId; }
    set workflowId(val) {
        this._workflowId = val;
        if (val) this._load();
    }

    _workflowId = null;

    async _load() {
        this.isLoading = true;
        try {
            const rows = await getVersionHistory({ workflowId: this._workflowId });
            this.versions = (rows ?? []).map(v => ({
                id         : v.Id,
                name       : v.Name,
                versionNum : v.Version_Number__c,
                savedBy    : v.Saved_By__r?.Name ?? '—',
                savedAt    : v.CreatedDate ? new Date(v.CreatedDate).toLocaleString() : '—',
                summary    : v.Change_Summary__c ?? '',
            }));
        } catch (e) {
            this._toast('Error', e.body?.message ?? e.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get hasVersions() { return this.versions.length > 0; }

    async handleRestore(event) {
        const versionId = event.currentTarget.dataset.id;
        // eslint-disable-next-line no-alert
        if (!confirm('Restore this version? Your current canvas will be overwritten. Save first if needed.')) return;
        this.restoringId = versionId;
        try {
            await restoreVersion({ workflowId: this._workflowId, versionId });
            this._toast('Restored', 'Canvas restored. Reload the workflow to see changes.', 'success');
            this.dispatchEvent(new CustomEvent('restored'));
        } catch (e) {
            this._toast('Restore Failed', e.body?.message ?? e.message, 'error');
        } finally {
            this.restoringId = null;
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleRefresh() {
        this._load();
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: message ?? '', variant }));
    }
}
