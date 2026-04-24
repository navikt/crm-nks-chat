import { LightningElement, api, wire } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getChatInfo from '@salesforce/apex/ChatAuthController.getMessagingInfo';
import setStatusRequested from '@salesforce/apex/ChatAuthController.setStatusRequested';
import getCommunityAuthUrl from '@salesforce/apex/ChatAuthControllerExperience.getCommunityAuthUrl';
import getCounselorName from '@salesforce/apex/ChatAuthController.getCounselorName';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';

import AUTH_STARTED from '@salesforce/label/c.CRM_Chat_Authentication_Started';
import IDENTITY_CONFIRMED_DISCLAIMER from '@salesforce/label/c.CRM_Chat_Identity_Confirmed_Disclaimer';
import SEND_AUTH_REQUEST from '@salesforce/label/c.NKS_Chat_Send_Authentication_Request';
import SET_TO_REDACTION_LABEL from '@salesforce/label/c.NKS_Set_To_Redaction';
import CHAT_LOGIN_MSG_NO from '@salesforce/label/c.NKS_Chat_Login_Message_NO';
import CHAT_LOGIN_MSG_EN from '@salesforce/label/c.NKS_Chat_Login_Message_EN';
import CHAT_GETTING_AUTH_STATUS from '@salesforce/label/c.NKS_Chat_Getting_Authentication_Status';
import CHAT_SENDING_AUTH_REQUEST from '@salesforce/label/c.NKS_Chat_Sending_Authentication_Request';

const STATUSES = {
    NOT_STARTED: 'Not Started',
    COMPLETED: 'Completed',
    AUTHREQUESTED: 'Authentication Requested',
    ACTIVE: 'Active'
};

export default class NksChatAuthenticationInfo extends LightningElement {
    @api recordId;
    @api loggingEnabled;
    @api chatEnded = false;

    labels = {
        AUTH_STARTED,
        IDENTITY_CONFIRMED_DISCLAIMER,
        SEND_AUTH_REQUEST,
        SET_TO_REDACTION_LABEL,
        CHAT_LOGIN_MSG_NO,
        CHAT_LOGIN_MSG_EN,
        CHAT_GETTING_AUTH_STATUS,
        CHAT_SENDING_AUTH_REQUEST
    };

    currentAuthenticationStatus;
    sendingAuthRequest = false;
    isActiveConversation;
    chatLanguage;
    chatAuthUrl;
    empApiSubscription = null;
    loginEvtSent = false;
    endTime = null;
    wiredRecordResult;

    connectedCallback() {
        this.loadAuthUrl();
        this.registerErrorListener();
    }

    disconnectedCallback() {
        this.handleUnsubscribe();
    }

    @wire(getChatInfo, { messagingId: '$recordId' })
    wiredResult(result) {
        this.wiredRecordResult = result;
        const { error, data } = result;

        if (data) {
            this.currentAuthenticationStatus = data.AUTH_STATUS;
            this.isActiveConversation = data.CONVERSATION_STATUS === STATUSES.ACTIVE;
            this.chatLanguage = data.CHAT_LANGUAGE;
            this.endTime = data.END_TIME;

            if (this.isEmpSubscriptionNeeded) {
                this.handleSubscribe();
            }
        } else if (error) {
            this.currentAuthenticationStatus = STATUSES.NOT_STARTED;
            this.handleError(error);
        }
    }

    registerErrorListener() {
        onError((error) => {
            this.handleError(error);
            this.handleUnsubscribe();
            this.handleSubscribe();
        });
    }

    handleSubscribe() {
        subscribe('/data/MessagingSessionChangeEvent', -1, this.handleCdcEvent.bind(this))
            .then((response) => {
                this.empApiSubscription = response;
                this.log(`Subscribed to: ${response.channel}`);
            })
            .catch((error) => this.handleError(error, 'Failed to subscribe'));
    }

    handleUnsubscribe() {
        if (!this.isEmpSubscribed) return;

        unsubscribe(this.empApiSubscription)
            .then(() => {
                this.empApiSubscription = null;
                this.log('Unsubscribed successfully');
            })
            .catch((error) => this.handleError(error, 'Failed to unsubscribe'));
    }

    handleCdcEvent(response) {
        const eventRecordIds = response.data.payload.ChangeEventHeader.recordIds;
        const changedFields = response.data.payload.ChangeEventHeader.changedFields;

        if (eventRecordIds.includes(this.recordId) && changedFields.includes('CRM_Authentication_Status__c')) {
            this.updateAuthStatus(response.data.payload.CRM_Authentication_Status__c);
        }
    }

    updateAuthStatus(newStatus) {
        this.currentAuthenticationStatus = newStatus;

        if (this.authenticationComplete) {
            this.sendLoginEvent();
            getRecordNotifyChange([{ recordId: this.recordId }]);
            this.refreshData();
            this.handleUnsubscribe();
        }
    }

    sendLoginEvent() {
        if (this.loginEvtSent) return;

        getCounselorName({ recordId: this.recordId })
            .then((name) => {
                const loginMessage =
                    this.chatLanguage === 'en_US'
                        ? `You are now in a secure chat with Nav, chatting with ${name}. ${this.flattenedLabels.CHAT_LOGIN_MSG_EN}`
                        : `Du er nå i en innlogget chat med Nav, du snakker med ${name}. ${this.flattenedLabels.CHAT_LOGIN_MSG_NO}`;

                this.dispatchEvent(new CustomEvent('authenticationcomplete', { detail: { loginMessage } }));
                this.loginEvtSent = true;
            })
            .catch((e) => this.handleError(e));
    }

    loadAuthUrl() {
        getCommunityAuthUrl()
            .then((url) => {
                this.chatAuthUrl = url;
            })
            .catch((error) => this.handleError(error, 'Failed to retrieve auth URL'));
    }

    requestAuthentication() {
        this.sendingAuthRequest = true;
        this.dispatchEvent(new CustomEvent('requestauthentication', { detail: { authUrl: this.chatAuthUrl } }));
    }

    setAuthStatusRequested() {
        setStatusRequested({ messagingId: this.recordId })
            .then(() => this.log('Status updated successfully'))
            .catch((e) => this.handleError(e))
            .finally(() => {
                this.sendingAuthRequest = false;
            });
    }

    @api
    authRequestHandling(success) {
        if (success) {
            this.setAuthStatusRequested();
            return;
        }

        this.sendingAuthRequest = false;
        this.showAuthError();
    }

    showAuthError() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Authentication error',
                message: this.flattenedLabels.SEND_AUTH_REQUEST,
                variant: 'error',
                mode: 'sticky'
            })
        );
    }

    handleError(error, context = '') {
        const message = context ? `${context}: ${JSON.stringify(error)}` : JSON.stringify(error);
        // eslint-disable-next-line no-console
        console.error(message);
    }

    log(loggable) {
        if (this.loggingEnabled) {
            // eslint-disable-next-line no-console
            console.log(loggable);
        }
    }

    refreshData() {
        if (this.wiredRecordResult) {
            refreshApex(this.wiredRecordResult);
        }
    }

    get isLoading() {
        return !this.currentAuthenticationStatus;
    }

    get cannotInitAuth() {
        return !(this.isActiveConversation && !this.sendingAuthRequest);
    }

    get isAuthenticating() {
        return this.currentAuthenticationStatus === STATUSES.AUTHREQUESTED;
    }

    get authenticationComplete() {
        return this.currentAuthenticationStatus === STATUSES.COMPLETED;
    }

    get isEmpSubscribed() {
        return !!this.empApiSubscription;
    }

    get isEmpSubscriptionNeeded() {
        return !this.authenticationComplete && !this.isEmpSubscribed && !this.isLoading;
    }

    get showAuthInfo() {
        return !this.endTime && !this.chatEnded;
    }

    get flattenedLabels() {
        const result = {};
        Object.keys(this.labels).forEach((key) => {
            result[key] = (this.labels[key] ?? '').replace(/\s+/g, ' ').trim();
        });
        return result;
    }
}
