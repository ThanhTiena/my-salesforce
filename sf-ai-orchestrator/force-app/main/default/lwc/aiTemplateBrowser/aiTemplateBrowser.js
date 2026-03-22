import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTemplates from '@salesforce/apex/WorkflowTemplateService.getTemplates';
import cloneTemplate from '@salesforce/apex/WorkflowTemplateService.cloneTemplate';

export default class AiTemplateBrowser extends LightningElement {
    @wire(getTemplates) wiredTemplates;
    @track isCloning = false;
    @track selectedTemplateId = null;
    @track newWorkflowName = '';
    @track showModal = false;

    get templates() { return this.wiredTemplates.data || []; }
    get hasTemplates() { return this.templates.length > 0; }
    get isEmpty() { return !this.wiredTemplates.isLoading && !this.hasTemplates && !this.isLoading; }
    get isLoading() { return !this.wiredTemplates.data && !this.wiredTemplates.error; }
    get isCloneDisabled() { return this.isCloning || !this.newWorkflowName.trim(); }

    handleUseTemplate(event) {
        this.selectedTemplateId = event.currentTarget.dataset.id;
        const tmpl = this.templates.find(t => t.Id === this.selectedTemplateId);
        this.newWorkflowName = 'Copy of ' + (tmpl?.Name || '');
        this.showModal = true;
    }

    handleNameChange(event) {
        this.newWorkflowName = event.detail.value;
    }

    handleModalClose() {
        this.showModal = false;
        this.selectedTemplateId = null;
        this.newWorkflowName = '';
    }

    async handleClone() {
        if (!this.newWorkflowName.trim()) return;
        this.isCloning = true;
        try {
            const newId = await cloneTemplate({
                templateId: this.selectedTemplateId,
                newName: this.newWorkflowName.trim(),
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Workflow Created',
                message: 'Workflow cloned successfully.',
                variant: 'success',
            }));
            this.dispatchEvent(new CustomEvent('workflowcreated', { detail: { workflowId: newId } }));
            this.handleModalClose();
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Clone Failed',
                message: e.body?.message ?? e.message,
                variant: 'error',
            }));
        } finally {
            this.isCloning = false;
        }
    }
}
