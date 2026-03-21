import { LightningElement, track } from 'lwc';

const NODE_DEFINITIONS = [
    {
        type        : 'START',
        label       : 'Start',
        icon        : '▶',
        description : 'Entry point — defines trigger criteria',
        category    : 'control',
        inputs      : 0,
        outputs     : 1,
    },
    {
        type        : 'END',
        label       : 'End',
        icon        : '⏹',
        description : 'Terminates the workflow and sets final status',
        category    : 'control',
        inputs      : 1,
        outputs     : 0,
    },
    {
        type        : 'AI_INFERENCE',
        label       : 'AI Inference',
        icon        : '🤖',
        description : 'Calls an AI provider with a configurable prompt template',
        category    : 'ai',
        inputs      : 1,
        outputs     : 2,
    },
    {
        type        : 'DECISION',
        label       : 'Decision',
        icon        : '◆',
        description : 'Evaluates a condition and routes to matching output path',
        category    : 'logic',
        inputs      : 1,
        outputs     : 2,
    },
    {
        type        : 'HTTP_CALLOUT',
        label       : 'HTTP Callout',
        icon        : '🌐',
        description : 'Makes an outbound REST call via a Named Credential',
        category    : 'integration',
        inputs      : 1,
        outputs     : 2,
    },
    {
        type        : 'APEX_ACTION',
        label       : 'Apex Action',
        icon        : '⚡',
        description : 'Invokes a custom Apex class implementing IOrchestrationAction',
        category    : 'integration',
        inputs      : 1,
        outputs     : 2,
    },
    {
        type        : 'FLOW_LAUNCH',
        label       : 'Launch Flow',
        icon        : '🔀',
        description : 'Launches a Salesforce Flow by API name and passes input variables',
        category    : 'integration',
        inputs      : 1,
        outputs     : 2,
    },
    {
        type        : 'WAIT',
        label       : 'Wait',
        icon        : '⏳',
        description : 'Pauses execution until a duration elapses or Platform Event fires',
        category    : 'logic',
        inputs      : 1,
        outputs     : 1,
    },
    {
        type        : 'LOOP',
        label       : 'Loop',
        icon        : '🔁',
        description : 'Iterates over a collection in the execution context',
        category    : 'logic',
        inputs      : 1,
        outputs     : 2,
    },
    {
        type        : 'SUBFLOW',
        label       : 'Sub-Workflow',
        icon        : '📦',
        description : 'Launches another AI Workflow as a nested child execution',
        category    : 'integration',
        inputs      : 1,
        outputs     : 2,
    },
    {
        type        : 'NOTIFICATION',
        label       : 'Notification',
        icon        : '🔔',
        description : 'Sends an email, Chatter post, or custom notification',
        category    : 'integration',
        inputs      : 1,
        outputs     : 1,
    },
];

const CATEGORY_COLORS = {
    control     : 'palette-node--control',
    ai          : 'palette-node--ai',
    logic       : 'palette-node--logic',
    integration : 'palette-node--integration',
};

export default class AiNodePalette extends LightningElement {

    @track searchTerm = '';

    get filteredNodes() {
        const term = this.searchTerm.toLowerCase().trim();
        return NODE_DEFINITIONS
            .filter(n => !term ||
                         n.label.toLowerCase().includes(term) ||
                         n.description.toLowerCase().includes(term))
            .map(n => ({
                ...n,
                cssClass: 'palette-node ' + (CATEGORY_COLORS[n.category] || ''),
            }));
    }

    get isEmpty() {
        return this.filteredNodes.length === 0;
    }

    handleSearch(event) {
        this.searchTerm = event.detail.value;
    }

    handleDragStart(event) {
        const nodeType = event.currentTarget.dataset.type;
        event.dataTransfer.setData('nodeType', nodeType);
        event.dataTransfer.effectAllowed = 'copy';
    }

    handleNodeClick(event) {
        const nodeType = event.currentTarget.dataset.type;
        // Dispatch so the parent shell can add the node at a default position
        this.dispatchEvent(new CustomEvent('nodeadd', {
            detail  : { nodeType },
            bubbles : true,
        }));
    }
}
