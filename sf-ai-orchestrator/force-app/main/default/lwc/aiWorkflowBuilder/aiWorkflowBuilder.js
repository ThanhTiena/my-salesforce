import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent }   from 'lightning/platformShowToastEvent';
import { refreshApex }      from '@salesforce/apex';
import getWorkflows         from '@salesforce/apex/WorkflowService.getWorkflows';
import createWorkflow       from '@salesforce/apex/WorkflowService.createWorkflow';
import getActiveProviders   from '@salesforce/apex/WorkflowService.getActiveProviders';

export default class AiWorkflowBuilder extends LightningElement {

    // ─── State ────────────────────────────────────────────────────────────────

    @track activeWorkflowId  = null;
    @track selectedNode      = null;
    @track showNewModal      = false;
    @track isCreating        = false;

    @track newWorkflowName   = '';
    @track newWorkflowDesc   = '';
    @track newWorkflowObject = '';

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
            const newId          = await createWorkflow({
                name         : this.newWorkflowName.trim(),
                description  : this.newWorkflowDesc,
                triggerObject: this.newWorkflowObject,
            });
            await refreshApex(this._workflowsWireResult);
            this.activeWorkflowId = newId;
            this.showNewModal     = false;
            this._showToast('Created', 'Workflow "' + this.newWorkflowName + '" created.', 'success');
        } catch (e) {
            this._showToast('Create Failed', e.body?.message ?? e.message, 'error');
        } finally {
            this.isCreating = false;
        }
    }

    // ─── Node palette → canvas ───────────────────────────────────────────────

    handleNodeAdd(event) {
        // Click-to-add from palette: place node at centre of canvas
        const { nodeType } = event.detail;
        this._getDesigner()?.addNode(nodeType, 300, 200);
    }

    // Drag-over: allow drop
    handleDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'copy';
    }

    // Drop: add node at drop position
    handleDrop(event) {
        event.preventDefault();
        const nodeType = event.dataTransfer.getData('nodeType');
        if (!nodeType) return;

        const canvasRect = event.currentTarget.getBoundingClientRect();
        const x = event.clientX - canvasRect.left;
        const y = event.clientY - canvasRect.top;
        this._getDesigner()?.addNode(nodeType, x, y);
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
        // Deselect to give visual feedback that apply worked
        this.selectedNode = { ...this.selectedNode, stepData };
    }

    handleStepDelete(event) {
        const { nodeId } = event.detail;
        // Tell Drawflow to remove the node (handled inside designer)
        const designer = this._getDesigner();
        if (designer) {
            // Drawflow exposes removeNodeId on the drawflow instance
            // We dispatch a custom event into the designer for it to handle
            designer.dispatchEvent(new CustomEvent('removenoderequest', {
                detail: { nodeId },
            }));
        }
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
