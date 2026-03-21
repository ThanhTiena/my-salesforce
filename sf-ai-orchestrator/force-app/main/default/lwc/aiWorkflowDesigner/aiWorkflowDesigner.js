import { LightningElement, api, track } from 'lwc';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import ORCHESTRATION_ENGINE from '@salesforce/resourceUrl/orchestrationEngine';
import getWorkflow        from '@salesforce/apex/WorkflowService.getWorkflow';
import saveWorkflow       from '@salesforce/apex/WorkflowService.saveWorkflow';
import saveSteps          from '@salesforce/apex/WorkflowService.saveSteps';
import setWorkflowActive  from '@salesforce/apex/WorkflowService.setWorkflowActive';
import runWorkflow        from '@salesforce/apex/WorkflowService.runWorkflow';

// Node types → Drawflow class mapping
const NODE_CLASSES = {
    START        : 'node-start',
    END          : 'node-end',
    AI_INFERENCE : 'node-ai',
    DECISION     : 'node-decision',
    HTTP_CALLOUT : 'node-http',
    APEX_ACTION  : 'node-apex',
    FLOW_LAUNCH  : 'node-flow',
    WAIT         : 'node-wait',
    LOOP         : 'node-loop',
    SUBFLOW      : 'node-subflow',
    NOTIFICATION : 'node-notification',
};

export default class AiWorkflowDesigner extends LightningElement {

    @api workflowId;

    @track workflow     = null;
    @track steps        = [];
    @track isLoading    = true;
    @track isSaving     = false;
    @track isDirty      = false;
    @track selectedNode = null;  // { nodeId, stepType, stepData }

    _drawflow         = null;
    _drawflowReady    = false;
    _drawflowInitTries = 0;

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        this._loadDrawflow();
    }

    renderedCallback() {
        // Drawflow must be attached to the DOM after render
        if (this._drawflowReady && !this._drawflow) {
            this._initDrawflow();
        }
    }

    disconnectedCallback() {
        if (this._drawflow) {
            this._drawflow.clear();
            this._drawflow = null;
        }
    }

    // ─── Drawflow Bootstrapping ───────────────────────────────────────────────

    async _loadDrawflow() {
        try {
            await Promise.all([
                loadScript(this, ORCHESTRATION_ENGINE + '/orchestrationEngine.js'),
                loadStyle(this,  ORCHESTRATION_ENGINE + '/orchestrationEngine.css'),
            ]);
            this._drawflowReady = true;
            this._initDrawflow();
        } catch (e) {
            this._showToast('Canvas Error', 'Failed to load designer canvas: ' + e.message, 'error');
            this.isLoading = false;
        }
    }

    _initDrawflow() {
        const wrapper = this.template.querySelector('[data-id="canvas"]');
        if (!wrapper) {
            // DOM not ready yet — renderedCallback will retry
            return;
        }

        // Drawflow is loaded as window.Drawflow via the UMD bundle
        // eslint-disable-next-line no-undef
        const DrawflowLib = window.Drawflow;
        if (!DrawflowLib) {
            this._showToast('Canvas Error', 'Drawflow library not found on window.', 'error');
            this.isLoading = false;
            return;
        }

        this._drawflow = new DrawflowLib(wrapper);
        this._drawflow.reroute          = true;
        this._drawflow.curvature        = 0.5;
        this._drawflow.line_path        = 5;
        this._drawflow.editor_mode      = 'edit';

        // Wire Drawflow events → LWC
        this._drawflow.on('nodeSelected',   (id) => this._onNodeSelected(id));
        this._drawflow.on('nodeUnselected', ()   => this._onNodeUnselected());
        this._drawflow.on('nodeCreated',    ()   => { this.isDirty = true; });
        this._drawflow.on('nodeRemoved',    ()   => { this.isDirty = true; });
        this._drawflow.on('connectionCreated', () => { this.isDirty = true; });
        this._drawflow.on('connectionRemoved', () => { this.isDirty = true; });

        this._drawflow.start();

        // Load workflow data
        this._loadWorkflow();
    }

    // ─── Data Loading ─────────────────────────────────────────────────────────

    async _loadWorkflow() {
        if (!this.workflowId) {
            this.isLoading = false;
            return;
        }
        try {
            const data      = await getWorkflow({ workflowId: this.workflowId });
            this.workflow   = data.workflow;
            this.steps      = data.steps || [];
            this._renderStepsOnCanvas(this.steps);
        } catch (e) {
            this._showToast('Load Error', e.body?.message ?? e.message, 'error');
        } finally {
            this.isLoading = false;
            this.isDirty   = false;
        }
    }

    _renderStepsOnCanvas(steps) {
        if (!this._drawflow || !steps.length) return;
        this._drawflow.clear();

        // Lay out nodes in a simple vertical chain; positions stored in step Name suffix
        // In a full implementation, position would be stored in a separate Canvas_JSON field.
        let x = 200;
        let y = 100;
        const spacing = 150;

        steps.forEach((step, idx) => {
            const nodeHtml = this._buildNodeHtml(step);
            this._drawflow.addNode(
                step.Id,           // name (unique key)
                1,                 // inputs
                step.Step_Type__c === 'START' ? 0 : (step.Step_Type__c === 'END' ? 0 : 2), // outputs: success + failure
                x, y + (idx * spacing),
                NODE_CLASSES[step.Step_Type__c] || 'node-default',
                { stepId: step.Id, stepType: step.Step_Type__c },
                nodeHtml
            );
        });
    }

    _buildNodeHtml(step) {
        const label = step.Name || step.Step_Type__c;
        const icon  = this._iconForType(step.Step_Type__c);
        return `<div class="df-node-inner">
                    <span class="df-node-icon">${icon}</span>
                    <span class="df-node-label">${label}</span>
                </div>`;
    }

    _iconForType(type) {
        const icons = {
            START:        '▶',
            END:          '⏹',
            AI_INFERENCE: '🤖',
            DECISION:     '◆',
            HTTP_CALLOUT: '🌐',
            APEX_ACTION:  '⚡',
            FLOW_LAUNCH:  '🔀',
            WAIT:         '⏳',
            LOOP:         '🔁',
            SUBFLOW:      '📦',
            NOTIFICATION: '🔔',
        };
        return icons[type] || '●';
    }

    // ─── Node Events ──────────────────────────────────────────────────────────

    _onNodeSelected(nodeId) {
        const nodeData = this._drawflow.getNodeFromId(nodeId);
        this.selectedNode = {
            nodeId,
            stepType : nodeData?.data?.stepType,
            stepData : nodeData?.data,
        };
        // Notify parent (aiWorkflowBuilder) to open properties panel
        this.dispatchEvent(new CustomEvent('nodeselect', { detail: this.selectedNode }));
    }

    _onNodeUnselected() {
        this.selectedNode = null;
        this.dispatchEvent(new CustomEvent('nodeunselect'));
    }

    // ─── Public API (called by parent aiWorkflowBuilder) ─────────────────────

    /**
     * Adds a new node from the palette. Called by the parent when user drags a node.
     * @param {String} stepType  - e.g. 'AI_INFERENCE'
     * @param {Number} x         - canvas x position
     * @param {Number} y         - canvas y position
     */
    @api
    addNode(stepType, x, y) {
        if (!this._drawflow) return;
        const tempId  = 'new_' + Date.now();
        const nodeHtml = this._buildNodeHtml({ Name: stepType, Step_Type__c: stepType });
        this._drawflow.addNode(
            tempId,
            stepType === 'START' ? 0 : 1,
            stepType === 'END'   ? 0 : 2,
            x || 200, y || 200,
            NODE_CLASSES[stepType] || 'node-default',
            { stepId: null, stepType },
            nodeHtml
        );
        this.isDirty = true;
    }

    /**
     * Updates the displayed label/data of a node after properties are saved.
     */
    @api
    updateNodeData(nodeId, stepData) {
        if (!this._drawflow) return;
        this._drawflow.updateNodeDataFromId(nodeId, stepData);
        this.isDirty = true;
    }

    // ─── Save ─────────────────────────────────────────────────────────────────

    async handleSave() {
        if (!this.workflow?.Id) return;
        this.isSaving = true;
        try {
            // Collect step order from canvas node positions
            const exportData  = this._drawflow.export();
            const nodeEntries = Object.entries(exportData?.drawflow?.Home?.data ?? {});

            const stepsToSave = nodeEntries.map(([, nodeObj], idx) => ({
                Id               : nodeObj.data?.stepId !== null ? nodeObj.data?.stepId : undefined,
                Name             : nodeObj.data?.stepType || 'Step ' + (idx + 1),
                AI_Workflow__c   : this.workflowId,
                Step_Type__c     : nodeObj.data?.stepType,
                Order__c         : idx + 1,
                Is_Active__c     : true,
                AI_Provider_Developer_Name__c : nodeObj.data?.providerDeveloperName,
                Model_Override__c             : nodeObj.data?.modelOverride,
                Prompt_Template__c            : nodeObj.data?.promptTemplate,
                System_Prompt__c              : nodeObj.data?.systemPrompt,
                Output_Field__c               : nodeObj.data?.outputField,
                Response_Format__c            : nodeObj.data?.responseFormat || 'TEXT',
                Temperature_Override__c       : nodeObj.data?.temperature,
                Max_Tokens_Override__c        : nodeObj.data?.maxTokens,
                Condition__c                  : nodeObj.data?.condition,
            }));

            await saveWorkflow({ workflow: this.workflow });
            await saveSteps({ workflowId: this.workflowId, steps: stepsToSave });

            this.isDirty = false;
            this._showToast('Saved', 'Workflow saved successfully.', 'success');
        } catch (e) {
            this._showToast('Save Failed', e.body?.message ?? e.message, 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async handleToggleActive() {
        if (!this.workflow?.Id) return;
        const newActive = !this.isActive;
        try {
            await setWorkflowActive({ workflowId: this.workflowId, isActive: newActive });
            this.workflow = { ...this.workflow, Is_Active__c: newActive };
            this._showToast(
                newActive ? 'Activated' : 'Deactivated',
                'Workflow is now ' + (newActive ? 'active' : 'inactive') + '.',
                'success'
            );
        } catch (e) {
            this._showToast('Error', e.body?.message ?? e.message, 'error');
        }
    }

    async handleRunNow() {
        if (!this.workflow?.Id) return;
        try {
            const execId = await runWorkflow({ workflowId: this.workflowId, triggerRecordId: null });
            this._showToast('Execution Started', 'Execution ID: ' + (execId ?? 'queued'), 'success');
            this.dispatchEvent(new CustomEvent('executionstarted', { detail: { execId } }));
        } catch (e) {
            this._showToast('Error', e.body?.message ?? e.message, 'error');
        }
    }

    // ─── Getters ─────────────────────────────────────────────────────────────

    get workflowName() {
        return this.workflow?.Name ?? 'New Workflow';
    }

    get isActive() {
        return this.workflow?.Is_Active__c === true;
    }

    get statusLabel() {
        return this.isActive ? 'Active' : 'Inactive';
    }

    get statusBadgeClass() {
        return this.isActive ? 'badge-success' : 'badge-neutral';
    }

    get isNotActive() {
        return !this.isActive;
    }

    get isEmpty() {
        return !this.isLoading && (!this._drawflow || this.steps.length === 0);
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
