import { LightningElement, api, wire } from 'lwc';
import { subscribe as empApiSubscribe, unsubscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import getChatInfo from '@salesforce/apex/ChatAuthController.getChatInfo';
import setStatusRequested from '@salesforce/apex/ChatAuthController.setStatusRequested';
import getCommunityAuthUrl from '@salesforce/apex/ChatAuthController.getCommunityAuthUrl';
import getCounselorName from '@salesforce/apex/ChatAuthController.getCounselorName';
import AUTH_STARTED from '@salesforce/label/c.CRM_Chat_Authentication_Started';
import IDENTITY_CONFIRMED_DISCLAIMER from '@salesforce/label/c.CRM_Chat_Identity_Confirmed_Disclaimer';
import SEND_AUTH_REQUEST from '@salesforce/label/c.NKS_Chat_Send_Authentication_Request';
import SET_TO_REDACTION_LABEL from '@salesforce/label/c.NKS_Set_To_Redaction';
import CHAT_LOGIN_MSG_NO from '@salesforce/label/c.NKS_Chat_Login_Message_NO';
import CHAT_LOGIN_MSG_EN from '@salesforce/label/c.NKS_Chat_Login_Message_EN';
import CHAT_GETTING_AUTH_STATUS from '@salesforce/label/c.NKS_Chat_Getting_Authentication_Status';
import CHAT_SENDING_AUTH_REQUEST from '@salesforce/label/c.NKS_Chat_Sending_Authentication_Request';
import { refreshApex } from '@salesforce/apex';

const STATUSES = {
    NOT_STARTED: 'Not Started',
    IN_PROGRESS: 'In Progress',
    COMPLETED: 'Completed',
    INPROGRESS: 'InProgress',
    AUTHREQUESTED: 'Authentication Requested'
};

export default class ChatAuthenticationOverview extends LightningElement {
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
    isActiveConversation = true;
    chatLanguage;
    chatAuthUrl;
    subscription = {};
    lmsSubscription = null;
    loginEvtSent = false;
    endTime = null;
    wiredRecordResult;

    @wire(getChatInfo, { chatTranscriptId: '$recordId' })
    wiredResult(result) {
        this.wiredRecordResult = result;
        const { error, data } = result;
        if (data) {
            this.currentAuthenticationStatus = data.AUTH_STATUS;
            this.isActiveConversation = data.CONVERSATION_STATUS === STATUSES.INPROGRESS;
            this.chatLanguage = data.CHAT_LANGUAGE;
            this.endTime = data.END_TIME;

            if (this.currentAuthenticationStatus !== STATUSES.COMPLETED && !this.isLoading && !this.isEmpSubscribed) {
                this.handleSubscribe();
            }
        } else {
            this.currentAuthenticationStatus = STATUSES.NOT_STARTED;
            this.log(error);
        }
    }

    connectedCallback() {
        this.getAuthUrl();
        this.registerErrorListener();
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
        return Object.keys(this.subscription).length !== 0 && this.subscription.constructor === Object;
    }

    get showAuthInfo() {
        return !this.endTime && !this.chatEnded;
    }

    registerErrorListener() {
        onError((error) => {
            console.error('Received error from empApi: ', JSON.stringify(error));
            this.handleUnsubscribe();
            this.handleSubscribe();
        });
    }

    getAuthUrl() {
        getCommunityAuthUrl({})
            .then((url) => {
                this.chatAuthUrl = url;
            })
            .catch((error) => {
                console.error('Failed to retrieve auth url: ', JSON.stringify(error));
            });
    }

    handleSubscribe() {
        const messageCallback = (response) => {
            const eventRecordId = response.data.sobject.Id;
            if (eventRecordId === this.recordId) {
                this.currentAuthenticationStatus = response.data.sobject.CRM_Authentication_Status__c;
                if (this.authenticationComplete) {
                    if (!this.loginEvtSent) this.sendLoginEvent();
                    getRecordNotifyChange([{ recordId: this.recordId }]);
                    this.refreshData();
                    this.handleUnsubscribe();
                }
            }
        };

        empApiSubscribe('/topic/Chat_Auth_Status_Changed', -1, messageCallback)
            .then((response) => {
                this.subscription = response;
                console.log('Successfully subscribed to: ', JSON.stringify(response.channel));
            })
            .catch((error) => {
                console.error('Failed to subscribe: ', JSON.stringify(error));
            });
    }

    handleUnsubscribe() {
        unsubscribe(this.subscription)
            .then((response) => {
                console.log('Unsubscribed: ', JSON.stringify(response));
            })
            .catch((error) => {
                console.error('EMP unsubscribe failed: ', JSON.stringify(error));
            });
    }

    sendLoginEvent() {
        getCounselorName({ recordId: this.recordId })
            .then((data) => {
                const loginMessage =
                    this.chatLanguage === 'en_US'
                        ? 'You are now in a secure chat with Nav, you are chatting with ' +
                          data +
                          '. ' +
                          this.labels.CHAT_LOGIN_MSG_EN
                        : 'Du er nå i en innlogget chat med Nav, du snakker med ' +
                          data +
                          '. ' +
                          this.labels.CHAT_LOGIN_MSG_NO;

                const authenticationCompleteEvt = new CustomEvent('authenticationcomplete', {
                    detail: { loginMessage }
                });
                this.dispatchEvent(authenticationCompleteEvt);
                this.loginEvtSent = true;
            })
            .catch((err) => {
                console.err(err);
            });
    }

    requestAuthentication() {
        this.sendingAuthRequest = true;
        const authUrl = this.chatAuthUrl;
        const requestAuthenticationEvent = new CustomEvent('requestauthentication', {
            detail: { authUrl }
        });
        this.dispatchEvent(requestAuthenticationEvent);
    }

    setAuthStatusRequested() {
        setStatusRequested({ chatTranscriptId: this.recordId })
            .then(() => {
                this.log('Successful update');
            })
            .catch((error) => {
                this.log(error);
            })
            .finally(() => {
                this.sendingAuthRequest = false;
            });
    }

    @api
    authRequestHandling(success) {
        if (success) {
            this.setAuthStatusRequested();
        } else {
            this.showAuthError();
        }
    }

    showAuthError() {
        const event = new ShowToastEvent({
            title: 'Authentication error',
            message: this.labels.authInitFailed,
            variant: 'error',
            mode: 'sticky'
        });
        this.dispatchEvent(event);
    }

    log(loggable) {
        if (this.loggingEnabled) console.log(loggable);
    }

    refreshData() {
        if (this.wiredRecordResult) {
            refreshApex(this.wiredRecordResult);
        }
    }
}
