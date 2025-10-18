import { LightningElement } from 'lwc';
import TIME_ZONE from '@salesforce/i18n/timeZone';

export default class Test extends LightningElement {

// This is a test file to check the i18n property
    connectedCallback() {
        debugger;
        console.log(TIME_ZONE);
    }
}