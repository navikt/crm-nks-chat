import { LightningElement, api, wire } from 'lwc';
import { subscribe as empApiSubscribe, unsubscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getChatInfo from '@salesforce/apex/ChatAuthController.getMessagingInfo';
import setStatusRequested from '@salesforce/apex/ChatAuthController.setStatusRequested';
import getCommunityAuthUrl from '@salesforce/apex/ChatAuthControllerExperience.getCommunityAuthUrl';
import getCounselorName from '@salesforce/apex/ChatAuthController.getCounselorName';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { publishToAmplitude } from 'c/amplitude';
import { refreshApex } from '@salesforce/apex';

//#### LABEL IMPORTS ####
import AUTH_REQUESTED from '@salesforce/label/c.CRM_Chat_Authentication_Requested';
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
    IN_PROGRESS: 'In Progress',
    COMPLETED: 'Completed',
    INPROGRESS: 'InProgress',
    AUTHREQUESTED: 'Authentication Requested'
};

export default class ChatAuthenticationOverview extends LightningElement {
    @api recordId;
    @api loggingEnabled; //Determines if console logging is enabled for the component

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

    @api objectApiName;
    @api accountFields; //Comma separated string with field names to display from the related account
    @api personFields; //Comma separated string with field names to display from the related accounts person
    @api copyPersonFields; //Comma separated string with field numbers to activate copy button

    accountId; //MessagingSession AccountId
    personId; //MessagingSession Account PersonId
    currentAuthenticationStatus; //Current auth status of the chat MessagingSession
    sendingAuthRequest = false; //Switch used to show spinner when initiatiing auth process
    activeConversation; //Boolean to determine if the componenet is rendered in a context on an active chat conversation
    chatLanguage;
    chatAuthUrl;
    subscription = {};
    lmsSubscription = null;
    loginEvtSent = false;
    nmbOfSecurityMeasures = 0;
    isNavEmployee = false;
    isConfidential = false;
    wiredRecordResult;

    @wire(getChatInfo, { messagingId: '$recordId' })
    wiredResult(result) {
        this.wiredRecordResult = result;
        const { error, data } = result;
        if (data) {
            this.currentAuthenticationStatus = data.AUTH_STATUS;
            this.activeConversation = data.CONVERSATION_STATUS === 'Active';
            this.accountId = data.ACCOUNTID;
            this.personId = data.PERSONID;
            this.nmbOfSecurityMeasures = parseInt(data.NMB_SECURITY_MEASURES, 10);
            // eslint-disable-next-line eqeqeq
            this.isNavEmployee = 'true' == data.IS_NAV_EMPLOYEE;
            // eslint-disable-next-line eqeqeq
            this.isConfidential = 'true' == data.IS_CONFIDENTIAL;
            this.chatLanguage = data.CHAT_LANGUAGE;

            if (this.isEmpSubscriptionNeeded) {
                this.handleSubscribe();
            }
        } else {
            this.currentAuthenticationStatus = 'Not Started';
            this.log(error);
        }
    }

    connectedCallback() {
        this.loadAuthUrl();
        this.registerErrorListener();
        publishToAmplitude('Chat Opened');
    }

    //#### GETTERS ####
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

    registerErrorListener() {
        onError((error) => {
            this.handleError(error);
            this.handleUnsubscribe();
            this.handleSubscribe();
        });
    }

    // Subscribes to CDC events when necessary
    handleSubscribe() {
        subscribe('/data/MessagingSessionChangeEvent', -1, this.handleCdcEvent.bind(this))
            .then((response) => {
                this.empApiSubscription = response;
                console.log(`Subscribed to: ${response.channel}`);
            })
            .catch((error) => this.handleError(error, 'Failed to subscribe'));
    }

    // Unsubscribes from CDC events
    handleUnsubscribe() {
        if (this.isEmpSubscribed) {
            unsubscribe(this.empApiSubscription)
                .then(() => {
                    this.empApiSubscription = null;
                    console.log('Unsubscribed successfully');
                })
                .catch((error) => this.handleError(error, 'Failed to unsubscribe'));
        }
    }

    // Handles incoming CDC events and updates authentication status
    handleCdcEvent(response) {
        const eventRecordIds = response.data.payload.ChangeEventHeader.recordIds;
        const changedFields = response.data.payload.ChangeEventHeader.changedFields;

        // Only process event if it's for the correct record and the field 'CRM_Authentication_Status__c' changed
        if (eventRecordIds.includes(this.recordId) && changedFields.includes('CRM_Authentication_Status__c')) {
            this.updateAuthStatus(response.data.payload.CRM_Authentication_Status__c);
        }
    }

    // Updates authentication status and triggers actions if necessary
    updateAuthStatus(newStatus) {
        this.currentAuthenticationStatus = newStatus;

        if (this.authenticationComplete) {
            this.sendLoginEvent();
            getRecordNotifyChange([{ recordId: this.recordId }]);
            this.refreshData();
            this.handleUnsubscribe(); // Unsubscribe after authentication is complete
        }
    }

    // Sends a custom event indicating login is complete
    sendLoginEvent() {
        if (!this.loginEvtSent) {
            getCounselorName({ recordId: this.recordId })
                .then((name) => {
                    const loginMessage =
                        this.chatLanguage === 'en_US'
                            ? `You are now in a secure chat with Nav, chatting with ${name}. ${this.labels.CHAT_LOGIN_MSG_EN}`
                            : `Du er nå i en innlogget chat med Nav, du snakker med ${name}. ${this.labels.CHAT_LOGIN_MSG_NO}`;

                    this.dispatchEvent(new CustomEvent('authenticationcomplete', { detail: { loginMessage } }));
                    this.loginEvtSent = true;
                })
                .catch(this.handleError);
        }
    }

    // Loads the community authentication URL
    loadAuthUrl() {
        getCommunityAuthUrl()
            .then((url) => {
                this.chatAuthUrl = url;
            })
            .catch((error) => this.handleError(error, 'Failed to retrieve auth URL'));
    }

    // Handles the authentication request
    requestAuthentication() {
        this.sendingAuthRequest = true;
        this.dispatchEvent(new CustomEvent('requestauthentication', { detail: { authUrl: this.chatAuthUrl } }));
    }

    // Sets authentication status to 'Requested'
    setAuthStatusRequested() {
        setStatusRequested({ messagingId: this.recordId })
            .then(() => console.log('Status updated successfully'))
            .catch(this.handleError)
            .finally(() => {
                this.sendingAuthRequest = false;
            });
    }

    // Handles success/failure in authentication request
    @api
    authRequestHandling(success) {
        if (success) {
            this.setAuthStatusRequested();
        } else {
            this.showAuthError();
        }
    }

    // Shows an error toast message if authentication fails
    showAuthError() {
        const event = new ShowToastEvent({
            title: 'Authentication error',
            message: this.labels.authInitFailed,
            variant: 'error',
            mode: 'sticky'
        });
        this.dispatchEvent(event);
    }

    // Error handling utility function
    handleError(error, context = '') {
        const message = context ? `${context}: ${JSON.stringify(error)}` : JSON.stringify(error);
        console.error(message);
    }

    // Logs messages if logging is enabled
    log(loggable) {
        if (this.loggingEnabled) console.log(loggable);
    }

    refreshData() {
        if (this.wiredRecordResult) {
            refreshApex(this.wiredRecordResult);
        }
    }
}
