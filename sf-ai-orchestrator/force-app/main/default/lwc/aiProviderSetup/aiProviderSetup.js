import { LightningElement, wire, track } from 'lwc';
import getActiveProviders from '@salesforce/apex/WorkflowService.getActiveProviders';

export default class AiProviderSetup extends LightningElement {

    @track providers = [];
    @track isLoading = true;

    @wire(getActiveProviders)
    wiredProviders({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.providers = data;
        } else if (error) {
            console.error('Failed to load providers:', error);
        }
    }

    get hasProviders() {
        return this.providers && this.providers.length > 0;
    }
}
