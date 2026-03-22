import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AiWorkflowExport extends LightningElement {
    @api workflowId;
    @api workflowName = 'workflow';
    @api canvasJson = '';   // JSON string from Drawflow export
    @track isImporting = false;
    @track importError = '';

    // ─── Export ───────────────────────────────────────────────────────────────

    handleExport() {
        if (!this.canvasJson) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Nothing to export',
                message: 'The canvas is empty.',
                variant: 'warning',
            }));
            return;
        }
        const blob = new Blob([this.canvasJson], { type: 'application/json' });
        const url  = URL.createObjectURL(blob);
        const a    = document.createElement('a');
        a.href     = url;
        a.download = (this.workflowName || 'workflow').replace(/\s+/g, '_') + '.json';
        a.click();
        URL.revokeObjectURL(url);
    }

    // ─── Import ───────────────────────────────────────────────────────────────

    handleImportClick() {
        this.template.querySelector('[data-id="fileInput"]').click();
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;
        this.importError = '';
        this.isImporting = true;

        const reader = new FileReader();
        reader.onload = (e) => {
            try {
                const json = e.target.result;
                JSON.parse(json); // validate it's valid JSON
                this.dispatchEvent(new CustomEvent('workflowimport', {
                    detail: { json },
                    bubbles: true,
                }));
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Imported',
                    message: 'Workflow canvas loaded from file.',
                    variant: 'success',
                }));
            } catch (err) {
                this.importError = 'Invalid JSON file: ' + err.message;
            } finally {
                this.isImporting = false;
            }
        };
        reader.onerror = () => {
            this.importError = 'Failed to read file.';
            this.isImporting = false;
        };
        reader.readAsText(file);
    }

    get hasImportError() { return !!this.importError; }
}
