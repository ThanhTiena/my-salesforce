import { LightningElement, api, track } from 'lwc';

const TOKEN_PILLS = [
    { token: '{{Lead.Name}}' },
    { token: '{{Lead.Company}}' },
    { token: '{{Lead.Email}}' },
    { token: '{{Case.Subject}}' },
    { token: '{{Case.Description}}' },
    { token: '{{Account.Name}}' },
    { token: '{{Contact.Name}}' },
];

const OBJECT_OPTIONS = [
    { label: 'Lead',    value: 'Lead'    },
    { label: 'Case',    value: 'Case'    },
    { label: 'Account', value: 'Account' },
    { label: 'Contact', value: 'Contact' },
];

const FIELD_OPTIONS = [
    { label: 'Name',        value: 'Name'        },
    { label: 'Subject',     value: 'Subject'     },
    { label: 'Description', value: 'Description' },
    { label: 'Email',       value: 'Email'       },
    { label: 'Company',     value: 'Company'     },
];

export default class AiPromptBuilder extends LightningElement {

    @api recordId;

    @track templateValue = '';
    @track selectedObject = 'Lead';
    @track selectedField  = 'Name';

    get tokenPills()    { return TOKEN_PILLS;    }
    get objectOptions() { return OBJECT_OPTIONS; }
    get fieldOptions()  { return FIELD_OPTIONS;  }

    get charCountDisplay() {
        const chars  = this.templateValue.length;
        const tokens = (this.templateValue.match(/\{\{[^}]+\}\}/g) || []).length;
        return chars + ' characters  |  ' + tokens + ' variable token(s)';
    }

    // ─── Handlers ─────────────────────────────────────────────────────────────

    handleTemplateChange(event) {
        this.templateValue = event.detail.value;
        this._dispatchPromptChange();
    }

    handlePillClick(event) {
        const token = event.currentTarget.dataset.token;
        this.templateValue = this.templateValue + token;
        this._dispatchPromptChange();
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
    }

    handleFieldChange(event) {
        this.selectedField = event.detail.value;
    }

    handleInsertToken() {
        if (!this.selectedObject || !this.selectedField) return;
        const token = '{{' + this.selectedObject + '.' + this.selectedField + '}}';
        this.templateValue = this.templateValue + token;
        this._dispatchPromptChange();
    }

    handleCopyPrompt() {
        if (navigator.clipboard) {
            navigator.clipboard.writeText(this.templateValue).catch(() => {});
        }
    }

    // ─── Private ──────────────────────────────────────────────────────────────

    _dispatchPromptChange() {
        this.dispatchEvent(new CustomEvent('promptchange', {
            detail: { value: this.templateValue },
            bubbles: true,
        }));
    }
}
