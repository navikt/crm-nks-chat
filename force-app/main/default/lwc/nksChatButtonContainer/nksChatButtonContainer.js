import { LightningElement, api } from 'lwc';
import CREATE_NAV_TASK_LABEL from '@salesforce/label/c.NKS_Create_NAV_Task';
import JOURNAL_LABEL from '@salesforce/label/c.NKS_Journal';
import SEND_TO_REDACTION_LABEL from '@salesforce/label/c.Set_To_Redaction';
import { publishToAmplitude } from 'c/amplitude';

export default class ChatButtonContainer extends LightningElement {
    @api recordId;

    showFlow = false;
    showRedact = false;
    showJournal = false;
    showCreateNavTask = false;
    labels = { SEND_TO_REDACTION_LABEL, CREATE_NAV_TASK_LABEL, JOURNAL_LABEL };
    label;

    get inputVariables() {
        return [
            {
                name: 'recordId',
                type: 'String',
                value: this.recordId
            }
        ];
    }

    toggleFlow(event) {
        this.showFlow = !this.showFlow;
        this.label = event.target.label;
        this.handleShowFlows();
        publishToAmplitude('Chat', { type: this.label + ' pressed' });
    }

    handleShowFlows() {
        this.showRedact = this.label === this.labels.SEND_TO_REDACTION_LABEL;
        this.showCreateNavTask = this.label === this.labels.CREATE_NAV_TASK_LABEL;
        this.showJournal = this.label === this.labels.JOURNAL_LABEL;
    }

    handleStatusChange(event) {
        let flowStatus = event.detail.status;
        if (flowStatus === 'FINISHED' || flowStatus === 'FINISHED_SCREEN') {
            this.showFlow = false;
        }
    }
}
