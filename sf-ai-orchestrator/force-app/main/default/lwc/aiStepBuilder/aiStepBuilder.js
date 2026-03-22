import { LightningElement, api, track, wire } from 'lwc';
import getActiveProviders from '@salesforce/apex/WorkflowService.getActiveProviders';

const NODE_LABELS = {
    START        : 'Start',
    END          : 'End',
    AI_INFERENCE : 'AI Inference',
    DECISION     : 'Decision',
    HTTP_CALLOUT : 'HTTP Callout',
    APEX_ACTION  : 'Apex Action',
    FLOW_LAUNCH  : 'Launch Flow',
    WAIT         : 'Wait',
    LOOP         : 'Loop',
    SUBFLOW      : 'Sub-Workflow',
    NOTIFICATION : 'Notification',
};

const NODE_ICONS = {
    START        : '\u25B6',
    END          : '\u23F9',
    AI_INFERENCE : '\uD83E\uDD16',
    DECISION     : '\u25C6',
    HTTP_CALLOUT : '\uD83C\uDF10',
    APEX_ACTION  : '\u26A1',
    FLOW_LAUNCH  : '\uD83D\uDD00',
    WAIT         : '\u23F3',
    LOOP         : '\uD83D\uDD01',
    SUBFLOW      : '\uD83D\uDCE6',
    NOTIFICATION : '\uD83D\uDD14',
};

export default class AiStepBuilder extends LightningElement {

    @api stepType = '';

    @api
    get stepData() { return this._stepData; }
    set stepData(val) {
        this._stepData = val;
        this._syncLocalData(val);
    }

    @track localData = {};
    @track _stepData = null;
    @track _providers = [];

    @wire(getActiveProviders)
    wiredProviders({ error, data }) {
        if (data) {
            this._providers = data;
        } else if (error) {
            this._providers = [];
        }
    }

    // ─── Getters ──────────────────────────────────────────────────────────────

    get nodeLabel()   { return NODE_LABELS[this.stepType] ?? this.stepType; }
    get nodeIcon()    { return NODE_ICONS[this.stepType]  ?? '\u25CF'; }
    get isAiInference() { return this.stepType === 'AI_INFERENCE'; }

    get providerOptions() {
        return (this._providers || []).map(p => ({ label: p.label, value: p.value }));
    }

    // ─── Handlers ─────────────────────────────────────────────────────────────

    handleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        this.localData = { ...this.localData, [field]: event.detail.value };
    }

    handleSystemPromptChange(event) {
        this.localData = { ...this.localData, systemPrompt: event.detail.value };
    }

    handleUserPromptChange(event) {
        this.localData = { ...this.localData, promptTemplate: event.detail.value };
    }

    handleApply() {
        this.dispatchEvent(new CustomEvent('stepupdate', {
            detail: { stepData: { ...this.localData } },
            bubbles: true,
        }));
    }

    // ─── Private ──────────────────────────────────────────────────────────────

    _syncLocalData(incoming) {
        this.localData = {
            providerDeveloperName : incoming?.providerDeveloperName ?? '',
            modelOverride         : incoming?.modelOverride         ?? '',
            temperature           : incoming?.temperature           ?? null,
            maxTokens             : incoming?.maxTokens             ?? null,
            systemPrompt          : incoming?.systemPrompt          ?? '',
            promptTemplate        : incoming?.promptTemplate        ?? '',
        };
    }
}
