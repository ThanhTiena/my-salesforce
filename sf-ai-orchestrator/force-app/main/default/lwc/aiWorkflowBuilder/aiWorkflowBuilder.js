import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent }   from 'lightning/platformShowToastEvent';
import { refreshApex }      from '@salesforce/apex';
import getWorkflows         from '@salesforce/apex/WorkflowService.getWorkflows';
import createWorkflow       from '@salesforce/apex/WorkflowService.createWorkflow';
import cloneTemplate        from '@salesforce/apex/WorkflowTemplateService.cloneTemplate';
import getActiveProviders   from '@salesforce/apex/WorkflowService.getActiveProviders';

export default class AiWorkflowBuilder extends LightningElement {

    // ─── State ────────────────────────────────────────────────────────────────

    @track activeWorkflowId  = null;
    @track selectedNode      = null;
    @track showNewModal      = false;
    @track showTemplateModal = false;  // shows the template list
    @track showCloneModal    = false;  // shows the "name your copy" dialog
    @track isCreating        = false;
    @track isCloning         = false;

    @track newWorkflowName   = '';
    @track newWorkflowDesc   = '';
    @track newWorkflowObject = '';

    @track _selectedTemplateId   = null;
    @track _selectedTemplateName = '';
    @track cloneWorkflowName     = '';

    _workflowsWireResult;
    providers = [];

    // ─── Wire: Workflow list ──────────────────────────────────────────────────

    @wire(getWorkflows)
    wiredWorkflows(result) {
        this._workflowsWireResult = result;
    }

    // ─── Wire: Providers (cached, used by properties panel) ──────────────────

    @wire(getActiveProviders)
    wiredProviders({ data, error }) {
        if (data)  this.providers = data;
        if (error) this._showToast('Provider Load Error', error.body?.message, 'warning');
    }

    // ─── Computed: workflow combobox options ──────────────────────────────────

    get workflowOptions() {
        const workflows = this._workflowsWireResult?.data ?? [];
        return workflows.map(w => ({
            label : w.Name + (w.Is_Active__c ? ' ✓' : ''),
            value : w.Id,
        }));
    }

    get isCloneDisabled() {
        return this.isCloning || !this.cloneWorkflowName.trim();
    }

    // ─── Workflow selection ───────────────────────────────────────────────────

    handleWorkflowSelect(event) {
        this.activeWorkflowId = event.detail.value;
        this.selectedNode     = null;
    }

    // ─── New Workflow Modal ───────────────────────────────────────────────────

    handleNewWorkflow() {
        this.newWorkflowName   = '';
        this.newWorkflowDesc   = '';
        this.newWorkflowObject = '';
        this.showNewModal      = true;
    }

    closeNewModal() {
        this.showNewModal = false;
    }

    handleNewNameChange(event)   { this.newWorkflowName   = event.detail.value; }
    handleNewDescChange(event)   { this.newWorkflowDesc   = event.detail.value; }
    handleNewObjectChange(event) { this.newWorkflowObject = event.detail.value; }

    async handleCreateWorkflow() {
        if (!this.newWorkflowName?.trim()) {
            this._showToast('Validation', 'Workflow name is required.', 'error');
            return;
        }
        this.isCreating = true;
        try {
            const newId = await createWorkflow({
                name         : this.newWorkflowName.trim(),
                description  : this.newWorkflowDesc,
                triggerObject: this.newWorkflowObject,
            });
            await refreshApex(this._workflowsWireResult);
            this.showNewModal     = false;
            this.activeWorkflowId = newId;
            this._showToast('Created', 'Workflow "' + this.newWorkflowName + '" created.', 'success');
        } catch (e) {
            this._showToast('Create Failed', e.body?.message ?? e.message, 'error');
        } finally {
            this.isCreating = false;
        }
    }

    // ─── Template Browser Modal ───────────────────────────────────────────────

    handleShowTemplates() {
        this.showTemplateModal = true;
        this.showCloneModal    = false;
    }

    closeTemplateModal() {
        this.showTemplateModal   = false;
        this.showCloneModal      = false;
        this._selectedTemplateId = null;
        this.cloneWorkflowName   = '';
    }

    // Fired by c-ai-template-browser when user clicks "Use Template"
    handleTemplateSelect(event) {
        this._selectedTemplateId   = event.detail.templateId;
        this._selectedTemplateName = event.detail.templateName;
        this.cloneWorkflowName     = 'Copy of ' + event.detail.templateName;
        this.showCloneModal        = true;   // switch to confirm step inside the same modal
    }

    handleCloneNameChange(event) {
        this.cloneWorkflowName = event.detail.value;
    }

    handleBackToTemplates() {
        this.showCloneModal = false;
    }

    async handleConfirmClone() {
        if (!this.cloneWorkflowName.trim()) return;
        this.isCloning = true;
        try {
            const newId = await cloneTemplate({
                templateId : this._selectedTemplateId,
                newName    : this.cloneWorkflowName.trim(),
            });
            await refreshApex(this._workflowsWireResult);
            this.closeTemplateModal();
            // Give LWC one tick to close modal / destroy old designer instance
            // before setting a new workflowId so renderedCallback fires cleanly
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.activeWorkflowId = newId;
                this.selectedNode     = null;
            }, 0);
            this._showToast('Created', '"' + this.cloneWorkflowName + '" created from template.', 'success');
        } catch (e) {
            this._showToast('Clone Failed', e.body?.message ?? e.message, 'error');
        } finally {
            this.isCloning = false;
        }
    }

    // ─── Node palette → canvas ───────────────────────────────────────────────

    handleNodeAdd(event) {
        const { nodeType } = event.detail;
        this._getDesigner()?.addNode(nodeType, null, null);
    }

    handleDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'copy';
    }

    handleDrop(event) {
        event.preventDefault();
        const nodeType = event.dataTransfer.getData('nodeType');
        if (!nodeType) return;
        this._getDesigner()?.addNode(nodeType, event.clientX, event.clientY);
    }

    // ─── Node selection → properties panel ───────────────────────────────────

    handleNodeSelect(event) {
        this.selectedNode = event.detail;
    }

    handleNodeUnselect() {
        this.selectedNode = null;
    }

    // ─── Properties panel → canvas update ────────────────────────────────────

    handleStepUpdate(event) {
        const { nodeId, stepData } = event.detail;
        this._getDesigner()?.updateNodeData(nodeId, stepData);
        this.selectedNode = { ...this.selectedNode, stepData };
    }

    handleStepDelete(event) {
        const { nodeId } = event.detail;
        this._getDesigner()?.removeNode(nodeId);
        this.selectedNode = null;
    }

    // ─── Execution feedback ───────────────────────────────────────────────────

    handleExecutionStarted(event) {
        const execId = event.detail?.execId;
        this._showToast(
            'Workflow Running',
            execId ? 'Execution ' + execId + ' queued.' : 'Execution queued.',
            'success'
        );
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    _getDesigner() {
        return this.template.querySelector('c-ai-workflow-designer');
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: message ?? '', variant }));
    }
}
