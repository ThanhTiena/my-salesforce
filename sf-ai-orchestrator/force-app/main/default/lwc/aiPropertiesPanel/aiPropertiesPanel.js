import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveProviders from '@salesforce/apex/WorkflowService.getActiveProviders';
import saveWorkflow from '@salesforce/apex/WorkflowService.saveWorkflow';

const TRIGGER_TYPES = [
    { value: 'MANUAL',          label: 'Manual',          icon: 'utility:touch_action',  hint: 'Run on demand only' },
    { value: 'RECORD_TRIGGER',  label: 'Record Trigger',  icon: 'utility:record',        hint: 'When a record is created or updated' },
    { value: 'SCHEDULED',       label: 'Scheduled',       icon: 'utility:clock',         hint: 'On a recurring schedule' },
    { value: 'PLATFORM_EVENT',  label: 'Platform Event',  icon: 'utility:connected_apps',hint: 'On a Platform Event message' },
];

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
    START        : '▶',
    END          : '⏹',
    AI_INFERENCE : '🤖',
    DECISION     : '◆',
    HTTP_CALLOUT : '🌐',
    APEX_ACTION  : '⚡',
    FLOW_LAUNCH  : '🔀',
    WAIT         : '⏳',
    LOOP         : '🔁',
    SUBFLOW      : '📦',
    NOTIFICATION : '🔔',
};

const HTTP_METHOD_OPTIONS = [
    { label: 'POST', value: 'POST' },
    { label: 'GET',  value: 'GET'  },
    { label: 'PUT',  value: 'PUT'  },
    { label: 'PATCH',value: 'PATCH'},
    { label: 'DELETE',value: 'DELETE'},
];

const RESPONSE_FORMAT_OPTIONS = [
    { label: 'Plain Text', value: 'TEXT' },
    { label: 'JSON',       value: 'JSON' },
];

const NOTIFICATION_TYPE_OPTIONS = [
    { label: 'Email',            value: 'EMAIL'   },
    { label: 'Chatter Post',     value: 'CHATTER' },
    { label: 'Custom Notification', value: 'CUSTOM' },
];

const STEP_TYPE_OPTIONS = [
    { label: 'AI Inference',      value: 'INFERENCE'      },
    { label: 'Classification',    value: 'CLASSIFICATION' },
    { label: 'Summarization',     value: 'SUMMARIZATION'  },
    { label: 'Sentiment Analysis',value: 'SENTIMENT'      },
    { label: 'Data Extraction',   value: 'EXTRACTION'     },
    { label: 'Translation',       value: 'TRANSLATION'    },
    { label: 'Embedding',         value: 'EMBEDDING'      },
    { label: 'Custom',            value: 'CUSTOM'         },
];

export default class AiPropertiesPanel extends LightningElement {

    // Selected node passed from parent (aiWorkflowBuilder)
    // Shape: { nodeId: String, stepType: String, stepData: Object }
    @api
    get selectedNode() { return this._selectedNode; }
    set selectedNode(val) {
        this._selectedNode = val;
        this._syncStepData(val?.stepData);
    }

    // Workflow record passed from parent for the Settings tab
    @api
    get workflow() { return this._workflow; }
    set workflow(val) {
        this._workflow = val;
        this._syncWorkflowData(val);
    }

    // Active providers loaded for the AI Inference combobox
    @api providers = [];

    @track stepData      = {};
    @track workflowData  = {};
    @track _selectedNode = null;
    @track _workflow     = null;
    @track _selectedProviderDefaultModel = '';
    @track isSavingWorkflow = false;

    // Wire not used here because providers is passed via @api from the parent
    // (parent caches the wire result to avoid re-querying per node selection)

    // ─── Getters: type guards ─────────────────────────────────────────────────

    get hasSelection()    { return !!this._selectedNode; }
    get hasWorkflow()     { return !!this._workflow; }
    get showSettings()    { return !this.hasSelection && this.hasWorkflow; }
    get nodeType()        { return this._selectedNode?.stepType; }
    get nodeLabel()       { return NODE_LABELS[this.nodeType] ?? this.nodeType; }
    get nodeIcon()        { return NODE_ICONS[this.nodeType]  ?? '●'; }

    get triggerTypes() {
        return TRIGGER_TYPES.map(t => ({
            ...t,
            isSelected    : this.workflowData.triggerType === t.value,
            cardClass     : 'trigger-card' + (this.workflowData.triggerType === t.value ? ' trigger-card--active' : ''),
        }));
    }

    get showRecordTriggerFields() { return this.workflowData.triggerType === 'RECORD_TRIGGER'; }
    get showScheduledFields()     { return this.workflowData.triggerType === 'SCHEDULED'; }
    get showPlatformEventFields() { return this.workflowData.triggerType === 'PLATFORM_EVENT'; }

    // Placeholders containing { or { must come from JS — LWC parses them as template expressions
    get promptPlaceholder()        { return 'e.g. Summarise the case: AccountName, Subject'; }
    get httpBodyPlaceholder()      { return '{"key": "value"}'; }
    get flowInputsPlaceholder()    { return '{"varName": "contextValue"}'; }
    get notificationPlaceholder()  { return 'e.g. Workflow complete. Output: see execution log.'; }

    get isAiInference()   { return this.nodeType === 'AI_INFERENCE';  }
    get isDecision()      { return this.nodeType === 'DECISION';      }
    get isHttpCallout()   { return this.nodeType === 'HTTP_CALLOUT';  }
    get isApexAction()    { return this.nodeType === 'APEX_ACTION';   }
    get isFlowLaunch()    { return this.nodeType === 'FLOW_LAUNCH';   }
    get isWait()          { return this.nodeType === 'WAIT';          }
    get isNotification()  { return this.nodeType === 'NOTIFICATION';  }
    get isSubflow()       { return this.nodeType === 'SUBFLOW';       }

    // Show generic condition for types that can be skipped
    get showCondition() {
        return !['START', 'END', 'DECISION'].includes(this.nodeType);
    }

    get providerOptions() {
        return (this.providers || []).map(p => ({ label: p.label, value: p.value }));
    }

    get defaultModelPlaceholder() {
        return this._selectedProviderDefaultModel
            ? 'Default: ' + this._selectedProviderDefaultModel
            : 'Use provider default';
    }

    get httpMethodOptions()       { return HTTP_METHOD_OPTIONS;        }
    get responseFormatOptions()   { return RESPONSE_FORMAT_OPTIONS;    }
    get notificationTypeOptions() { return NOTIFICATION_TYPE_OPTIONS;  }
    get stepTypeOptions()         { return STEP_TYPE_OPTIONS;          }

    // ─── Field change handlers ────────────────────────────────────────────────

    handleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        this.stepData = { ...this.stepData, [field]: event.detail.value };
    }

    handleCheckboxChange(event) {
        const field = event.currentTarget.dataset.field;
        this.stepData = { ...this.stepData, [field]: event.detail.checked };
    }

    handleProviderChange(event) {
        const value    = event.detail.value;
        const provider = (this.providers || []).find(p => p.value === value);
        this._selectedProviderDefaultModel = provider?.defaultModel ?? '';
        this.stepData  = { ...this.stepData, providerDeveloperName: value };
    }

    // ─── Workflow settings handlers ───────────────────────────────────────────

    handleTriggerTypeSelect(event) {
        const val = event.currentTarget.dataset.value;
        this.workflowData = { ...this.workflowData, triggerType: val };
    }

    handleWorkflowFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        this.workflowData = { ...this.workflowData, [field]: event.detail.value };
    }

    async handleSaveWorkflowSettings() {
        if (!this._workflow?.Id) return;
        this.isSavingWorkflow = true;
        try {
            await saveWorkflow({
                workflow: {
                    Id                    : this._workflow.Id,
                    Name                  : this.workflowData.name,
                    Description__c        : this.workflowData.description,
                    Trigger_Object__c     : this.workflowData.triggerObject,
                    Trigger_Type__c       : this.workflowData.triggerType,
                    Trigger_Condition__c  : this.workflowData.triggerCondition,
                    Max_Retries__c        : this.workflowData.maxRetries,
                    Notification_Email__c : this.workflowData.notificationEmail,
                },
            });
            this.dispatchEvent(new CustomEvent('workflowsettingssaved', { bubbles: true }));
            this.dispatchEvent(new ShowToastEvent({ title: 'Saved', message: 'Workflow settings updated.', variant: 'success' }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Save Failed', message: e.body?.message ?? e.message, variant: 'error' }));
        } finally {
            this.isSavingWorkflow = false;
        }
    }

    // ─── Apply / Delete ───────────────────────────────────────────────────────

    handleApply() {
        if (!this._validate()) return;
        this.dispatchEvent(new CustomEvent('stepupdate', {
            detail: {
                nodeId   : this._selectedNode.nodeId,
                stepData : { ...this.stepData },
            },
            bubbles: true,
        }));
    }

    handleDelete() {
        this.dispatchEvent(new CustomEvent('stepdelete', {
            detail  : { nodeId: this._selectedNode.nodeId },
            bubbles : true,
        }));
    }

    // ─── Private helpers ──────────────────────────────────────────────────────

    _syncWorkflowData(wf) {
        this.workflowData = {
            name              : wf?.Name                  ?? '',
            description       : wf?.Description__c        ?? '',
            triggerObject     : wf?.Trigger_Object__c     ?? '',
            triggerType       : wf?.Trigger_Type__c       ?? 'MANUAL',
            triggerCondition  : wf?.Trigger_Condition__c  ?? '',
            maxRetries        : wf?.Max_Retries__c        ?? 3,
            notificationEmail : wf?.Notification_Email__c ?? '',
        };
    }

    _syncStepData(incoming) {
        this.stepData = {
            name                  : incoming?.name                  ?? '',
            isActive              : incoming?.isActive              ?? true,
            providerDeveloperName : incoming?.providerDeveloperName ?? '',
            modelOverride         : incoming?.modelOverride         ?? '',
            aiStepSubtype         : incoming?.aiStepSubtype         ?? 'INFERENCE',
            systemPrompt          : incoming?.systemPrompt          ?? '',
            promptTemplate        : incoming?.promptTemplate        ?? '',
            outputField           : incoming?.outputField           ?? '',
            responseFormat        : incoming?.responseFormat        ?? 'TEXT',
            temperature           : incoming?.temperature           ?? null,
            maxTokens             : incoming?.maxTokens             ?? null,
            condition             : incoming?.condition             ?? '',
            namedCredential       : incoming?.namedCredential       ?? '',
            httpPath              : incoming?.httpPath              ?? '',
            httpMethod            : incoming?.httpMethod            ?? 'POST',
            httpBody              : incoming?.httpBody              ?? '',
            apexClassName         : incoming?.apexClassName         ?? '',
            flowApiName           : incoming?.flowApiName           ?? '',
            flowInputs            : incoming?.flowInputs            ?? '',
            waitMinutes           : incoming?.waitMinutes           ?? 5,
            resumeEvent           : incoming?.resumeEvent           ?? '',
            notificationType      : incoming?.notificationType      ?? 'EMAIL',
            notificationMessage   : incoming?.notificationMessage   ?? '',
            notificationRecipient : incoming?.notificationRecipient ?? '',
            childWorkflowName     : incoming?.childWorkflowName     ?? '',
        };

        // Set default model placeholder if provider already selected
        if (this.stepData.providerDeveloperName && this.providers?.length) {
            const p = this.providers.find(x => x.value === this.stepData.providerDeveloperName);
            this._selectedProviderDefaultModel = p?.defaultModel ?? '';
        }
    }

    _validate() {
        const inputs = this.template.querySelectorAll(
            'lightning-input[required], lightning-textarea[required], lightning-combobox[required]'
        );
        let valid = true;
        inputs.forEach(el => {
            el.reportValidity();
            if (!el.checkValidity()) valid = false;
        });
        return valid;
    }
}
