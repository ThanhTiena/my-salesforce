import { LightningElement, track } from 'lwc';

export default class AiOrchestrationDashboard extends LightningElement {

    @track activeTab = 'monitor';

    get tabMonitor()        { return this.activeTab === 'monitor'; }
    get tabMonitorClass()   { return 'dash-tab' + (this.activeTab === 'monitor'   ? ' dash-tab--active' : ''); }
    get tabProvidersClass() { return 'dash-tab' + (this.activeTab === 'providers' ? ' dash-tab--active' : ''); }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }
}
