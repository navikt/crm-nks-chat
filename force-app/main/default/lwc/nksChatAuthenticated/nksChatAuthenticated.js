import { LightningElement } from 'lwc';
import setStatusCompleted from '@salesforce/apex/ChatAuthControllerExperience.setStatusCompleted';

export default class NksChatAuthenticated extends LightningElement {
    connectedCallback() {
        const messagingId = this.getUrlParamValue(window.location.href, 'ctid');

        setStatusCompleted({ messagingId: messagingId })
            .then((result) => {
                console.log(result);
            })
            .catch((error) => {
                console.log(error);
            });

        // eslint-disable-next-line @lwc/lwc/no-async-operation, @locker/locker/distorted-window-set-timeout
        setTimeout(function () {
            window.close();
        }, 5000);
    }

    getUrlParamValue(url, key) {
        // eslint-disable-next-line compat/compat
        return new URL(url).searchParams.get(key);
    }
}
