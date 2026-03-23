import { LightningElement, track, wire } from 'lwc';
import getTemplates from '@salesforce/apex/WorkflowTemplateService.getTemplates';

export default class AiTemplateBrowser extends LightningElement {
    @wire(getTemplates) wiredTemplates;

    get templates()    { return this.wiredTemplates.data || []; }
    get hasTemplates() { return this.templates.length > 0; }
    get isLoading()    { return !this.wiredTemplates.data && !this.wiredTemplates.error; }
    get isEmpty()      { return !this.isLoading && !this.hasTemplates; }

    handleUseTemplate(event) {
        const templateId   = event.currentTarget.dataset.id;
        const templateName = event.currentTarget.dataset.name;
        // Notify parent to open the confirmation/name dialog
        this.dispatchEvent(new CustomEvent('templateselect', {
            detail: { templateId, templateName },
        }));
    }
}
