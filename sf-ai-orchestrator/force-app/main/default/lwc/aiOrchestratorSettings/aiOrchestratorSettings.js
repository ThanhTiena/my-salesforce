import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProviderDetails from '@salesforce/apex/WorkflowService.getProviderDetails';
import getDashboardMetrics from '@salesforce/apex/AIExecutionMonitorController.getDashboardMetrics';
import getTokenUsageByProvider from '@salesforce/apex/AIExecutionMonitorController.getTokenUsageByProvider';

export default class AiOrchestratorSettings extends LightningElement {

    @track activeTab    = 'providers';
    @track providers    = [];
    @track tokenUsage   = [];
    @track metrics      = {};
    @track isLoading    = true;

    connectedCallback() {
        this._load();
    }

    async _load() {
        this.isLoading = true;
        try {
            const [providers, metrics, tokenUsage] = await Promise.all([
                getProviderDetails(),
                getDashboardMetrics({ daysBack: 30 }),
                getTokenUsageByProvider({ daysBack: 30 }),
            ]);
            this.providers  = providers ?? [];
            this.metrics    = metrics ?? {};
            this.tokenUsage = (tokenUsage ?? []).map(t => ({
                ...t,
                rpmPercent: t.rpmUsed && t.rpmLimit
                    ? Math.min(100, Math.round(t.rpmUsed / t.rpmLimit * 100)) : 0,
            }));
        } catch (e) {
            this._toast('Load Error', e.body?.message ?? e.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get tabProviders()   { return this.activeTab === 'providers'; }
    get tabRateLimits()  { return this.activeTab === 'rate-limits'; }
    get tabMongoDB()     { return this.activeTab === 'mongodb'; }
    get hasProviders()   { return this.providers.length > 0; }
    get hasTokenUsage()  { return this.tokenUsage.length > 0; }

    get tabClass() {
        return (tab) => 'settings-tab' + (this.activeTab === tab ? ' settings-tab--active' : '');
    }
    get tabProvidersClass()   { return 'settings-tab' + (this.activeTab === 'providers'    ? ' settings-tab--active' : ''); }
    get tabRateLimitsClass()  { return 'settings-tab' + (this.activeTab === 'rate-limits'  ? ' settings-tab--active' : ''); }
    get tabMongoDBClass()     { return 'settings-tab' + (this.activeTab === 'mongodb'      ? ' settings-tab--active' : ''); }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    handleRefresh() { this._load(); }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: message ?? '', variant }));
    }
}
