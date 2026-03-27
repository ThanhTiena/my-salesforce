import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getWorkflow       from '@salesforce/apex/WorkflowService.getWorkflow';
import saveWorkflow      from '@salesforce/apex/WorkflowService.saveWorkflow';
import saveSteps         from '@salesforce/apex/WorkflowService.saveSteps';
import setWorkflowActive from '@salesforce/apex/WorkflowService.setWorkflowActive';
import runWorkflow       from '@salesforce/apex/WorkflowService.runWorkflow';

// ─── Node type metadata ───────────────────────────────────────────────────────
const NODE_META = {
    START        : { icon: '▶', label: 'Start',        color: '#2e844a', hasInput: false, hasOutput: true  },
    END          : { icon: '⏹', label: 'End',          color: '#ba0517', hasInput: true,  hasOutput: false },
    AI_INFERENCE : { icon: '🤖', label: 'AI Inference', color: '#1b96ff', hasInput: true,  hasOutput: true  },
    DECISION     : { icon: '◆',  label: 'Decision',     color: '#ff9e2c', hasInput: true,  hasOutput: true  },
    HTTP_CALLOUT : { icon: '🌐', label: 'HTTP Callout', color: '#6b7280', hasInput: true,  hasOutput: true  },
    APEX_ACTION  : { icon: '⚡', label: 'Apex Action',  color: '#7c3aed', hasInput: true,  hasOutput: true  },
    FLOW_LAUNCH  : { icon: '🔀', label: 'Launch Flow',  color: '#0284c7', hasInput: true,  hasOutput: true  },
    WAIT         : { icon: '⏳', label: 'Wait',         color: '#9a3b14', hasInput: true,  hasOutput: true  },
    LOOP         : { icon: '🔁', label: 'Loop',         color: '#1d4ed8', hasInput: true,  hasOutput: true  },
    SUBFLOW      : { icon: '📦', label: 'Sub-Workflow', color: '#374151', hasInput: true,  hasOutput: true  },
    NOTIFICATION : { icon: '🔔', label: 'Notification', color: '#059669', hasInput: true,  hasOutput: true  },
};

const NODE_W = 160;
const NODE_H = 56;

let _idCounter = 0;
function genId() { return 'n' + (++_idCounter); }
function connId(fromId, toId) { return fromId + '->' + toId; }

// Cubic bezier path between two points
function bezierPath(x1, y1, x2, y2) {
    const dx = Math.abs(x2 - x1) * 0.5;
    return `M${x1},${y1} C${x1 + dx},${y1} ${x2 - dx},${y2} ${x2},${y2}`;
}

/**
 * Serialise per-type config fields into Condition__c.
 * AI_INFERENCE uses dedicated SF fields — Condition__c stays as the skip condition.
 * All other handler types pack their config as JSON into Condition__c.
 */
function _buildConditionJson(type, d) {
    switch (type) {
        case 'DECISION':
            // Plain string — kept as-is (e.g. "CONTEXT_KEY==value")
            return d.condition || null;
        case 'HTTP_CALLOUT':
            return JSON.stringify({
                namedCredential : d.namedCredential || '',
                path            : d.httpPath        || '',
                method          : d.httpMethod      || 'POST',
                body            : d.httpBody        || null,
                timeoutMs       : d.timeoutMs       || 10000,
            });
        case 'APEX_ACTION':
            return JSON.stringify({ className: d.apexClassName || '' });
        case 'FLOW_LAUNCH': {
            let inputVars = {};
            if (d.flowInputs) {
                try { inputVars = JSON.parse(d.flowInputs); } catch (e) { /* ignore */ }
            }
            return JSON.stringify({ flowApiName: d.flowApiName || '', inputVariables: inputVars });
        }
        case 'NOTIFICATION':
            return JSON.stringify({
                toAddress : d.notificationRecipient || '',
                subject   : d.notificationSubject   || '',
                body      : d.notificationMessage   || '',
            });
        case 'LOOP':
            return JSON.stringify({
                collectionKey : d.collectionKey || '',
                itemKey       : d.itemKey       || 'item',
                indexKey      : d.indexKey      || 'index',
            });
        case 'WAIT':
            return JSON.stringify({ delayMinutes: d.waitMinutes || 5 });
        case 'SUBFLOW':
            return JSON.stringify({ childWorkflowName: d.childWorkflowName || '' });
        default:
            // START, END, AI_INFERENCE — no handler config needed
            return d.condition || null;
    }
}

/**
 * Parse Condition__c back into per-type stepData fields when loading a step.
 * Merges with the AI-inference-specific fields already extracted from dedicated columns.
 */
function _parseConditionJson(type, conditionValue, aiFields) {
    const base = { ...aiFields, condition: null };
    if (!conditionValue) return base;

    // Non-JSON types keep condition as-is
    if (type === 'DECISION' || type === 'START' || type === 'END' || type === 'AI_INFERENCE') {
        return { ...base, condition: conditionValue };
    }

    let cfg = {};
    try { cfg = JSON.parse(conditionValue); } catch (e) { return base; }

    switch (type) {
        case 'HTTP_CALLOUT':
            return { ...base, namedCredential: cfg.namedCredential, httpPath: cfg.path, httpMethod: cfg.method || 'POST', httpBody: cfg.body, timeoutMs: cfg.timeoutMs };
        case 'APEX_ACTION':
            return { ...base, apexClassName: cfg.className };
        case 'FLOW_LAUNCH':
            return { ...base, flowApiName: cfg.flowApiName, flowInputs: cfg.inputVariables ? JSON.stringify(cfg.inputVariables) : '' };
        case 'NOTIFICATION':
            return { ...base, notificationRecipient: cfg.toAddress, notificationSubject: cfg.subject, notificationMessage: cfg.body };
        case 'LOOP':
            return { ...base, collectionKey: cfg.collectionKey, itemKey: cfg.itemKey || 'item', indexKey: cfg.indexKey || 'index' };
        case 'WAIT':
            return { ...base, waitMinutes: cfg.delayMinutes || 5 };
        case 'SUBFLOW':
            return { ...base, childWorkflowName: cfg.childWorkflowName };
        default:
            return base;
    }
}

export default class AiWorkflowDesigner extends LightningElement {

    // ─── Public API ───────────────────────────────────────────────────────────

    @api
    get workflowId() { return this._workflowId; }
    set workflowId(val) {
        this._workflowId = val;
        this._loadWorkflow();
    }

    // Called by parent to add a node.
    // x/y are client (screen) coordinates — pass null to place at canvas centre.
    @api
    addNode(stepType, x, y) {
        let canvasPos;
        if (x != null && y != null) {
            canvasPos = this._toCanvas(x, y);
        } else {
            // Default: visible centre offset
            const svg = this.template.querySelector('[data-id="canvas"]');
            const cx = svg ? svg.clientWidth  / 2 : 300;
            const cy = svg ? svg.clientHeight / 2 : 200;
            canvasPos = { x: (cx - this._panOffset.x) / this._zoom, y: (cy - this._panOffset.y) / this._zoom };
        }
        // Stagger overlapping nodes
        const offset = this._nodes.length * 20;
        this._addNodeInternal(stepType, canvasPos.x + offset, canvasPos.y + offset, null, null, {});
        this.isDirty = true;
    }

    // Called by parent to remove a node (from properties panel delete)
    @api
    removeNode(nodeId) {
        this._removeNode(nodeId);
        this.dispatchEvent(new CustomEvent('nodeunselect'));
    }

    // Called by parent after properties panel applies changes
    @api
    updateNodeData(nodeId, stepData) {
        const idx = this._nodes.findIndex(n => n.id === nodeId);
        if (idx === -1) return;
        const old = this._nodes[idx];
        const label = stepData?.name || old.label;
        this._nodes[idx] = { ...old, label, data: { ...old.data, ...stepData } };
        this._refreshNodes();
        this.isDirty = true;
    }

    // ─── State ────────────────────────────────────────────────────────────────

    @track nodes        = [];   // view models for SVG rendering
    @track connections  = [];   // { id, fromId, toId, path }
    @track isLoading    = false;
    @track isSaving     = false;
    @track isDirty      = false;

    // internal mutable node list (same objects, no track overhead)
    _nodes = [];
    _workflowId = null;
    workflow    = null;

    // Layout direction: 'vertical' (top→bottom) | 'horizontal' (left→right)
    _layoutDirection = 'vertical';

    // Drag state
    _drag       = null;  // { type:'node'|'canvas'|'port', nodeId?, startX, startY, startNodeX?, startNodeY? }
    _panOffset  = { x: 0, y: 0 };
    _zoom       = 1;

    // Connection drawing state
    drawingConnection = false;
    drawingPath       = '';
    _drawingFrom      = null;  // { nodeId, x, y }

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        this._boundMouseMove = this.handleMouseMove.bind(this);
        this._boundMouseUp   = this.handleMouseUp.bind(this);
    }

    renderedCallback() {
        // Apply the viewport transform after every render.
        // This covers the case where _applyViewport() was called while the SVG
        // wasn't in the DOM yet (e.g. immediately after workflowId is set).
        this._applyViewport();
    }

    disconnectedCallback() {
        document.removeEventListener('mousemove', this._boundMouseMove);
        document.removeEventListener('mouseup',   this._boundMouseUp);
    }

    // ─── Data loading ─────────────────────────────────────────────────────────

    async _loadWorkflow() {
        if (!this._workflowId) {
            this._clearCanvas();
            return;
        }
        this.isLoading = true;
        this.isDirty   = false;
        try {
            const data    = await getWorkflow({ workflowId: this._workflowId });
            this.workflow = data.workflow;
            const steps   = data.steps || [];
            this._importFromJson(this.workflow?.Canvas_JSON__c, steps);

            // If any step that requires JSON config has a blank Condition__c (e.g. saved
            // before the _buildConditionJson fix was deployed), mark dirty so the next save
            // will migrate the config from node.data into Condition__c automatically.
            const JSON_CONFIG_TYPES = new Set(['NOTIFICATION', 'HTTP_CALLOUT', 'APEX_ACTION', 'FLOW_LAUNCH', 'LOOP', 'WAIT', 'SUBFLOW']);
            if (steps.some(s => JSON_CONFIG_TYPES.has(s.Step_Type__c) && !s.Condition__c)) {
                this.isDirty = true;
            }

            // Notify parent with workflow record so properties panel can show settings
            this.dispatchEvent(new CustomEvent('workflowloaded', { detail: { workflow: this.workflow } }));
        } catch (e) {
            this._showToast('Load Error', e.body?.message ?? e.message, 'error');
        } finally {
            this.isLoading = false;
            this.isDirty   = false;
        }
    }

    _clearCanvas() {
        this._nodes      = [];
        this._panOffset  = { x: 0, y: 0 };
        this._zoom       = 1;
        this.workflow    = null;
        this.isDirty     = false;
        this._refreshNodes();
        this._refreshConnections();
        this._applyViewport();
    }

    _importFromJson(canvasJson, steps) {
        this._nodes = [];
        this.connections = [];

        if (canvasJson) {
            try {
                const saved = JSON.parse(canvasJson);
                if (saved && saved.nodes) {
                    this._nodes = saved.nodes.map(n => {
                        const meta = NODE_META[n.type] || { hasInput: true, hasOutput: true };
                        return {
                            id        : n.id,
                            type      : n.type,
                            sfId      : n.sfId || null,
                            label     : n.label,
                            x         : n.x,
                            y         : n.y,
                            data      : n.data || {},
                            hasInput  : meta.hasInput,
                            hasOutput : meta.hasOutput,
                        };
                    });
                    this._refreshNodes();

                    if (saved.connections) {
                        this.connections = saved.connections
                            .filter(c => {
                                const fromNode = this._nodes.find(n => n.id === c.fromId);
                                const toNode   = this._nodes.find(n => n.id === c.toId);
                                return fromNode && toNode;
                            })
                            .map(c => this._buildConnection(c.fromId, c.toId));
                    }
                    if (saved.pan)  this._panOffset = saved.pan;
                    if (saved.zoom) this._zoom       = saved.zoom;
                    this._applyViewport();
                    return;
                }
            } catch (e) {
                // malformed JSON — fall through to auto-layout
            }
        }

        // Auto-layout: arrange steps according to current direction
        const isHoriz  = this._layoutDirection === 'horizontal';
        const SPACING  = isHoriz ? NODE_W + 80 : NODE_H + 100;
        let x = 80, y = 80;
        steps.forEach((step, idx) => {
            this._addNodeInternal(
                step.Step_Type__c,
                isHoriz ? x + idx * SPACING : x,
                isHoriz ? y                  : y + idx * SPACING,
                step.Id,
                step.Name,
                _parseConditionJson(step.Step_Type__c, step.Condition__c, {
                    providerDeveloperName : step.AI_Provider_Developer_Name__c,
                    modelOverride         : step.Model_Override__c,
                    promptTemplate        : step.Prompt_Template__c,
                    systemPrompt          : step.System_Prompt__c,
                    outputField           : step.Output_Field__c,
                    responseFormat        : step.Response_Format__c || 'TEXT',
                    temperature           : step.Temperature_Override__c,
                    maxTokens             : step.Max_Tokens_Override__c,
                })
            );
        });

        // Auto-connect sequential steps
        for (let i = 0; i < this._nodes.length - 1; i++) {
            const from = this._nodes[i];
            const to   = this._nodes[i + 1];
            if (from.hasOutput && to.hasInput && !this._connectionExists(from.id, to.id)) {
                this.connections = [...this.connections, this._buildConnection(from.id, to.id)];
            }
        }

        this._panOffset = { x: 0, y: 0 };
        this._zoom      = 1;
        this._applyViewport();
    }

    // ─── Node management ──────────────────────────────────────────────────────

    _addNodeInternal(type, x, y, sfId, label, data) {
        const meta  = NODE_META[type] || { icon: '●', label: type, color: '#dddbda', hasInput: true, hasOutput: true };
        const id    = sfId ? ('sf_' + sfId) : genId();
        const node  = {
            id,
            type,
            sfId      : sfId || null,
            label     : label || meta.label,
            x, y,
            data      : data || {},
            hasInput  : meta.hasInput,
            hasOutput : meta.hasOutput,
        };
        this._nodes = [...this._nodes, node];
        this._refreshNodes();
        return node;
    }

    _removeNode(nodeId) {
        this._nodes      = this._nodes.filter(n => n.id !== nodeId);
        this.connections = this.connections.filter(c => c.fromId !== nodeId && c.toId !== nodeId);
        this._refreshNodes();
        this.isDirty = true;
    }

    // Converts raw node data into SVG view model
    _toViewModel(node) {
        const meta = NODE_META[node.type] || { icon: '●', label: node.type, color: '#dddbda', hasInput: true, hasOutput: true };
        const isSelected = this._selectedNodeId === node.id;
        const isHoriz = this._layoutDirection === 'horizontal';

        // Port positions differ by layout direction:
        //   horizontal → output on right, input on left
        //   vertical   → output on bottom centre, input on top centre
        const outPortX = isHoriz ? node.x + NODE_W          : node.x + NODE_W / 2;
        const outPortY = isHoriz ? node.y + NODE_H / 2      : node.y + NODE_H;
        const inPortX  = isHoriz ? node.x                   : node.x + NODE_W / 2;
        const inPortY  = isHoriz ? node.y + NODE_H / 2      : node.y;

        return {
            id           : node.id,
            type         : node.type,
            x            : node.x,
            y            : node.y,
            data         : node.data,
            displayLabel : node.label || meta.label,
            icon         : meta.icon,
            hasInput     : meta.hasInput,
            hasOutput    : meta.hasOutput,
            groupClass   : 'node-group',
            rectClass    : 'node-rect node-' + node.type.toLowerCase().replace(/_/g, '-') + (isSelected ? ' node-selected' : ''),
            iconX        : node.x + 20,
            iconY        : node.y + NODE_H / 2,
            labelX       : node.x + 36,
            labelY       : node.y + NODE_H / 2,
            outPortX, outPortY,
            inPortX,  inPortY,
        };
    }

    _selectedNodeId = null;

    _refreshNodes() {
        this.nodes = this._nodes.map(n => this._toViewModel(n));
    }

    _refreshConnections() {
        this.connections = this.connections.map(c => this._buildConnection(c.fromId, c.toId));
    }

    _buildConnection(fromId, toId) {
        const from    = this._nodes.find(n => n.id === fromId);
        const to      = this._nodes.find(n => n.id === toId);
        if (!from || !to) return null;
        const isHoriz = this._layoutDirection === 'horizontal';
        const x1 = isHoriz ? from.x + NODE_W     : from.x + NODE_W / 2;
        const y1 = isHoriz ? from.y + NODE_H / 2 : from.y + NODE_H;
        const x2 = isHoriz ? to.x                : to.x + NODE_W / 2;
        const y2 = isHoriz ? to.y + NODE_H / 2   : to.y;
        return { id: connId(fromId, toId), fromId, toId, path: bezierPath(x1, y1, x2, y2), tipX: x2, tipY: y2 };
    }

    _connectionExists(fromId, toId) {
        const id = connId(fromId, toId);
        return this.connections.some(c => c.id === id);
    }

    // ─── Viewport (pan / zoom) ────────────────────────────────────────────────

    _applyViewport() {
        const vp = this.template.querySelector('[data-id="viewport"]');
        if (vp) {
            vp.setAttribute('transform',
                `translate(${this._panOffset.x},${this._panOffset.y}) scale(${this._zoom})`);
        }
    }

    // Converts screen coords to canvas coords (accounting for pan/zoom)
    _toCanvas(screenX, screenY) {
        const svg = this.template.querySelector('[data-id="canvas"]');
        if (!svg) return { x: screenX, y: screenY };
        const rect = svg.getBoundingClientRect();
        return {
            x: (screenX - rect.left - this._panOffset.x) / this._zoom,
            y: (screenY - rect.top  - this._panOffset.y) / this._zoom,
        };
    }

    handleWheel(event) {
        event.preventDefault();
        const delta  = event.deltaY > 0 ? 0.9 : 1.1;
        this._zoom   = Math.min(2, Math.max(0.3, this._zoom * delta));
        this._applyViewport();
    }

    // ─── Mouse events ─────────────────────────────────────────────────────────

    handleCanvasMouseDown(event) {
        // Only plain left-click on the SVG background starts panning
        if (event.target !== event.currentTarget) return;
        event.preventDefault();
        this._drag = {
            type   : 'canvas',
            startX : event.clientX - this._panOffset.x,
            startY : event.clientY - this._panOffset.y,
        };
        document.addEventListener('mousemove', this._boundMouseMove);
        document.addEventListener('mouseup',   this._boundMouseUp);
        // Deselect node
        this._selectedNodeId = null;
        this._refreshNodes();
        this.dispatchEvent(new CustomEvent('nodeunselect'));
    }

    handleNodeMouseDown(event) {
        // Port mousedown handled separately — stop here if it's a port
        if (event.target.classList.contains('port')) return;
        event.stopPropagation();
        event.preventDefault();

        const nodeId = event.currentTarget.dataset.nodeId;
        const node   = this._nodes.find(n => n.id === nodeId);
        if (!node) return;

        // Select node
        this._selectedNodeId = nodeId;
        this._refreshNodes();

        this._drag = {
            type       : 'node',
            nodeId,
            startX     : event.clientX,
            startY     : event.clientY,
            startNodeX : node.x,
            startNodeY : node.y,
            moved      : false,
        };
        document.addEventListener('mousemove', this._boundMouseMove);
        document.addEventListener('mouseup',   this._boundMouseUp);
    }

    handlePortMouseDown(event) {
        event.stopPropagation();
        event.preventDefault();
        const nodeId = event.currentTarget.dataset.nodeId;
        const node   = this._nodes.find(n => n.id === nodeId);
        if (!node) return;

        const fromX = node.x + NODE_W;
        const fromY = node.y + NODE_H / 2;
        this._drawingFrom      = { nodeId, x: fromX, y: fromY };
        this.drawingConnection = true;
        this.drawingPath       = bezierPath(fromX, fromY, fromX, fromY);

        document.addEventListener('mousemove', this._boundMouseMove);
        document.addEventListener('mouseup',   this._boundMouseUp);
    }

    handlePortMouseUp(event) {
        if (!this.drawingConnection) return;
        event.stopPropagation();
        const toNodeId = event.currentTarget.dataset.nodeId;
        if (toNodeId && toNodeId !== this._drawingFrom?.nodeId) {
            if (!this._connectionExists(this._drawingFrom.nodeId, toNodeId)) {
                const conn = this._buildConnection(this._drawingFrom.nodeId, toNodeId);
                if (conn) {
                    this.connections = [...this.connections, conn];
                    this.isDirty = true;
                }
            }
        }
        this._cancelDraw();
    }

    handleMouseMove(event) {
        if (this.drawingConnection && this._drawingFrom) {
            const pos = this._toCanvas(event.clientX, event.clientY);
            this.drawingPath = bezierPath(
                this._drawingFrom.x, this._drawingFrom.y,
                pos.x, pos.y
            );
            return;
        }
        if (!this._drag) return;

        if (this._drag.type === 'canvas') {
            this._panOffset = {
                x: event.clientX - this._drag.startX,
                y: event.clientY - this._drag.startY,
            };
            this._applyViewport();
        } else if (this._drag.type === 'node') {
            const dx = (event.clientX - this._drag.startX) / this._zoom;
            const dy = (event.clientY - this._drag.startY) / this._zoom;
            const idx = this._nodes.findIndex(n => n.id === this._drag.nodeId);
            if (idx === -1) return;
            this._nodes[idx] = {
                ...this._nodes[idx],
                x: this._drag.startNodeX + dx,
                y: this._drag.startNodeY + dy,
            };
            this._drag.moved = true;
            this._refreshNodes();
            this._refreshConnections();
        }
    }

    handleMouseUp(event) {
        if (this.drawingConnection) {
            this._cancelDraw();
            return;
        }
        if (this._drag?.type === 'node' && !this._drag.moved) {
            // It was a click: fire nodeselect
            const node = this._nodes.find(n => n.id === this._drag.nodeId);
            if (node) {
                this.dispatchEvent(new CustomEvent('nodeselect', {
                    detail: {
                        nodeId   : node.id,
                        stepType : node.type,
                        stepData : node.data,
                    },
                }));
            }
        } else if (this._drag?.type === 'node' && this._drag.moved) {
            this.isDirty = true;
        }
        this._drag = null;
        document.removeEventListener('mousemove', this._boundMouseMove);
        document.removeEventListener('mouseup',   this._boundMouseUp);
    }

    handleConnectionClick(event) {
        const connId = event.currentTarget.dataset.connId;
        if (connId) {
            // Remove connection on click
            this.connections = this.connections.filter(c => c.id !== connId);
            this.isDirty = true;
        }
    }

    _cancelDraw() {
        this.drawingConnection = false;
        this.drawingPath       = '';
        this._drawingFrom      = null;
        this._drag             = null;
        document.removeEventListener('mousemove', this._boundMouseMove);
        document.removeEventListener('mouseup',   this._boundMouseUp);
    }

    // ─── Save ─────────────────────────────────────────────────────────────────

    async handleSave() {
        if (!this._workflowId) return;
        this.isSaving = true;
        try {
            const canvasState = {
                nodes       : this._nodes.map(n => ({ id: n.id, type: n.type, label: n.label, x: n.x, y: n.y, data: n.data, sfId: n.sfId })),
                connections : this.connections.map(c => ({ fromId: c.fromId, toId: c.toId })),
                pan         : this._panOffset,
                zoom        : this._zoom,
            };
            const canvasJson = JSON.stringify(canvasState);

            const stepsToSave = this._nodes.map((node, idx) => {
                const d = node.data || {};
                return {
                    Id               : node.sfId || undefined,
                    Name             : node.label || node.type,
                    AI_Workflow__c   : this._workflowId,
                    Step_Type__c     : node.type,
                    Order__c         : idx + 1,
                    Is_Active__c     : d.isActive !== false,
                    AI_Provider_Developer_Name__c : d.providerDeveloperName || null,
                    Model_Override__c             : d.modelOverride         || null,
                    Prompt_Template__c            : d.promptTemplate        || null,
                    System_Prompt__c              : d.systemPrompt          || null,
                    Output_Field__c               : d.outputField           || null,
                    Response_Format__c            : d.responseFormat        || 'TEXT',
                    Temperature_Override__c       : d.temperature           || null,
                    Max_Tokens_Override__c        : d.maxTokens             || null,
                    Condition__c                  : _buildConditionJson(node.type, d),
                };
            });

            const workflowToSave = { ...this.workflow, Canvas_JSON__c: canvasJson };
            await saveWorkflow({ workflow: workflowToSave });
            await saveSteps({ workflowId: this._workflowId, steps: stepsToSave });

            this.workflow = { ...this.workflow, Canvas_JSON__c: canvasJson };
            this.isDirty  = false;
            this._showToast('Saved', 'Workflow saved successfully.', 'success');
        } catch (e) {
            this._showToast('Save Failed', e.body?.message ?? e.message, 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async handleToggleActive() {
        if (!this._workflowId) return;
        const newActive = !this.isActive;
        try {
            await setWorkflowActive({ workflowId: this._workflowId, isActive: newActive });
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
        if (!this._workflowId) return;
        try {
            const execId = await runWorkflow({ workflowId: this._workflowId, triggerRecordId: null });
            this._showToast('Execution Started', 'Execution ID: ' + (execId ?? 'queued'), 'success');
            this.dispatchEvent(new CustomEvent('executionstarted', { detail: { execId } }));
        } catch (e) {
            this._showToast('Error', e.body?.message ?? e.message, 'error');
        }
    }

    // ─── Layout direction ─────────────────────────────────────────────────────

    handleLayoutVertical() {
        if (this._layoutDirection === 'vertical') return;
        this._layoutDirection = 'vertical';
        this._reLayout();
    }

    handleLayoutHorizontal() {
        if (this._layoutDirection === 'horizontal') return;
        this._layoutDirection = 'horizontal';
        this._reLayout();
    }

    // Re-arrange all existing nodes in the current direction, rebuild connections
    _reLayout() {
        if (!this._nodes.length) return;
        const isHoriz  = this._layoutDirection === 'horizontal';
        const SPACING  = isHoriz ? NODE_W + 80 : NODE_H + 100;
        const startX   = 80;
        const startY   = 80;

        this._nodes = this._nodes.map((node, idx) => ({
            ...node,
            x: isHoriz ? startX + idx * SPACING : startX,
            y: isHoriz ? startY                  : startY + idx * SPACING,
        }));

        this._refreshNodes();
        this._refreshConnections();
        this._panOffset = { x: 0, y: 0 };
        this._applyViewport();
        this.isDirty = true;
    }

    // ─── Getters ─────────────────────────────────────────────────────────────

    get workflowName()     { return this.workflow?.Name ?? 'New Workflow'; }
    get isActive()         { return this.workflow?.Is_Active__c === true; }
    get statusLabel()      { return this._workflowId ? (this.isActive ? 'Active' : 'Inactive') : ''; }
    get statusBadgeClass() { return this.isActive ? 'badge-success' : 'badge-neutral'; }
    get isEmpty()          { return !this.isLoading && !!this._workflowId && this._nodes.length === 0; }

    get layoutBtnVertical() {
        return 'layout-btn' + (this._layoutDirection === 'vertical' ? ' layout-btn--active' : '');
    }
    get layoutBtnHorizontal() {
        return 'layout-btn' + (this._layoutDirection === 'horizontal' ? ' layout-btn--active' : '');
    }

    // ── Button disable conditions ──────────────────────────────────────────────
    get isSaveDisabled()       { return this.isSaving || !this._workflowId; }
    get isActivateDisabled()   { return !this._workflowId || this.isDirty || this._nodes.length === 0; }
    get isDeactivateDisabled() { return !this._workflowId; }
    get isRunDisabled()        { return !this._workflowId || !this.isActive; }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
