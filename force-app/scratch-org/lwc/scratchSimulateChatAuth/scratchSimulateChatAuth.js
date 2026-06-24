import { LightningElement } from 'lwc';
import setStatusCompleted from '@salesforce/apex/ChatAuthControllerExperience.setStatusCompleted';

export default class ScratchSimulateChatAuth extends LightningElement {
    loading = false;
    errorMsg;

    initAuth() {
        let messagingId = this.inputField.value;
        console.log('INIT AUTH: ' + messagingId);
        if (messagingId && messagingId !== '') {
            this.loading = true;
            this.errorMsg = null;
            setStatusCompleted({ messagingId: messagingId })
                .then((result) => {
                    console.log(result);
                })
                .catch((error) => {
                    console.log(error);
                    this.errorMsg = error.body.message;
                })
                .finally(() => {
                    this.loading = false;
                });
        }
    }

    get inputField() {
        return this.template.querySelector('lightning-input');
    }
}
