import { LightningElement, api, wire } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getChatInfo from '@salesforce/apex/ChatAuthController.getChatInfo';
import setStatusRequested from '@salesforce/apex/ChatAuthController.setStatusRequested';
import getCommunityAuthUrl from '@salesforce/apex/ChatAuthController.getCommunityAuthUrl';
import getCouncellorName from '@salesforce/apex/ChatAuthController.getCouncellorName';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import AUTH_STARTED from '@salesforce/label/c.CRM_Chat_Authentication_Started';
import UNCONFIRMED_IDENTITY_WARNING from '@salesforce/label/c.CRM_Chat_Unconfirmed_Identity_Warning';
import IDENTITY_CONFIRMED_DISCLAIMER from '@salesforce/label/c.CRM_Chat_Identity_Confirmed_Disclaimer';
import AUTH_INIT_FAILED from '@salesforce/label/c.CRM_Chat_Authentication_Init_Failed';
import CHAT_LOGIN_MSG_NO from '@salesforce/label/c.NKS_Chat_Login_Message_NO';
import CHAT_LOGIN_MSG_EN from '@salesforce/label/c.NKS_Chat_Login_Message_EN';

export default class ChatAuthenticationOverview extends LightningElement {
    @api recordId;
    @api loggingEnabled;
    @api councellorName;

    labels = {
        AUTH_STARTED,
        UNCONFIRMED_IDENTITY_WARNING,
        IDENTITY_CONFIRMED_DISCLAIMER,
        AUTH_INIT_FAILED
    };
    currentAuthenticationStatus;
    sendingAuthRequest = false;
    activeConversation;
    chatLanguage;
    chatAuthUrl;
    subscription = {};
    loginEvtSent = false;

    get isLoading() {
        return this.currentAuthenticationStatus ? false : true;
    }

    get cannotInitAuth() {
        return !(this.activeConversation && !this.sendingAuthRequest);
    }

    get authenticationRequested() {
        return this.currentAuthenticationStatus !== 'Not Started';
    }

    get authenticationStarted() {
        return this.currentAuthenticationStatus === 'In Progress' || this.currentAuthenticationStatus === 'Completed';
    }

    get authenticationComplete() {
        return this.currentAuthenticationStatus === 'Completed';
    }

    get isEmpSubscribed() {
        return Object.keys(this.subscription).length !== 0 && this.subscription.constructor === Object;
    }

    connectedCallback() {
        this.getAuthUrl();
        this.registerErrorListener();
    }

    registerErrorListener() {
        onError((error) => {
            console.log('Received error from empApi: ', JSON.stringify(error));
            this.handleUnsubscribe();
            this.handleSubscribe();
        });
    }

    @wire(getChatInfo, { chatTranscriptId: '$recordId' })
    wiredStatus({ error, data }) {
        if (data) {
            this.log(data);
            this.currentAuthenticationStatus = data.AUTH_STATUS;
            this.activeConversation = data.CONVERSATION_STATUS === 'InProgress';
            this.chatLanguage = data.CHAT_LANGUAGE;

            if (this.currentAuthenticationStatus !== 'Completed' && !this.isLoading && !this.isEmpSubscribed) {
                this.handleSubscribe();
            }
        } else {
            this.currentAuthenticationStatus = 'Not Started';
            this.log(error);
        }
    }

    getAuthUrl() {
        getCommunityAuthUrl({})
            .then((url) => {
                this.chatAuthUrl = url;
            })
            .catch((error) => {
                console.log('Failed to retrieve auth url: ' + JSON.stringify(error, null, 2));
            });
    }

    handleSubscribe() {
        let _this = this;
        const messageCallback = function (response) {
            console.log('AUTH STATUS UPDATED');
            const eventRecordId = response.data.sobject.Id;
            if (eventRecordId === _this.recordId) {
                _this.currentAuthenticationStatus = response.data.sobject.CRM_Authentication_Status__c;
                if (_this.authenticationComplete) {
                    if (!_this.loginEvtSent) _this.sendLoginEvent();
                    getRecordNotifyChange([{ recordId: _this.recordId }]);
                    _this.handleUnsubscribe();
                }
            }
        };

        subscribe('/topic/Chat_Auth_Status_Changed' /*?Id=" + this.recordId*/, -1, messageCallback).then((response) => {
            this.subscription = response;
            console.log('Successfully subscribed to : ', JSON.stringify(response.channel));
        });
    }

    handleUnsubscribe() {
        unsubscribe(this.subscription, (response) => {
            console.log('Unsubscribed: ', JSON.stringify(response));
        })
            .then(() => {
                this.log('Successful unsubscribe');
            })
            .catch((error) => {
                console.log('EMP unsubscribe failed: ' + JSON.stringify(error, null, 2));
            });
    }

    sendLoginEvent() {
        getCouncellorName({ recordId: this.recordId }).then((data) => {
            this.councellorName = data;
            const loginMessage =
                this.chatLanguage === 'en_US'
                    ? 'You are now in a secure chat with NAV, you are chatting with ' +
                      this.councellorName +
                      '. ' +
                      CHAT_LOGIN_MSG_EN
                    : 'Du er nå i en innlogget chat med NAV, du snakker med ' +
                      this.councellorName +
                      '. ' +
                      CHAT_LOGIN_MSG_NO;

            const authenticationCompleteEvt = new CustomEvent('authenticationcomplete', {
                detail: { loginMessage }
            });
            this.dispatchEvent(authenticationCompleteEvt);
            this.loginEvtSent = true;
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
            message: AUTH_INIT_FAILED,
            variant: 'error',
            mode: 'sticky'
        });
        this.dispatchEvent(event);
    }

    log(loggable) {
        if (this.loggingEnabled) console.log(loggable);
    }
}
