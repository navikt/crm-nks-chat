import { LightningElement, api, wire } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getChatInfo from '@salesforce/apex/ChatAuthController.getChatInfo';
import setStatusRequested from '@salesforce/apex/ChatAuthController.setStatusRequested';
import getCommunityAuthUrl from '@salesforce/apex/ChatAuthController.getCommunityAuthUrl';
import getCounselorName from '@salesforce/apex/ChatAuthController.getCounselorName';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { publishToAmplitude } from 'c/amplitude';

//#### LABEL IMPORTS ####
import AUTH_REQUESTED from '@salesforce/label/c.CRM_Chat_Authentication_Requested';
import AUTH_STARTED from '@salesforce/label/c.CRM_Chat_Authentication_Started';
import IDENTITY_CONFIRMED from '@salesforce/label/c.CRM_Chat_Identity_Confirmed';
import UNCONFIRMED_IDENTITY_WARNING from '@salesforce/label/c.CRM_Chat_Unconfirmed_Identity_Warning';
import IDENTITY_CONFIRMED_DISCLAIMER from '@salesforce/label/c.CRM_Chat_Identity_Confirmed_Disclaimer';
import AUTH_INIT_FAILED from '@salesforce/label/c.CRM_Chat_Authentication_Init_Failed';
import SEND_AUTH_REQUEST from '@salesforce/label/c.NKS_Chat_Send_Authentication_Request';
import CHAT_LOGIN_MSG_NO from '@salesforce/label/c.NKS_Chat_Login_Message_NO';
import CHAT_LOGIN_MSG_EN from '@salesforce/label/c.NKS_Chat_Login_Message_EN';
import CHAT_GETTING_AUTH_STATUS from '@salesforce/label/c.NKS_Chat_Getting_Authentication_Status';
import CHAT_SENDING_AUTH_REQUEST from '@salesforce/label/c.NKS_Chat_Sending_Authentication_Request';

export default class ChatAuthenticationOverview extends LightningElement {
    labels = {
        AUTH_REQUESTED,
        AUTH_STARTED,
        IDENTITY_CONFIRMED,
        UNCONFIRMED_IDENTITY_WARNING,
        IDENTITY_CONFIRMED_DISCLAIMER,
        AUTH_INIT_FAILED,
        SEND_AUTH_REQUEST,
        CHAT_LOGIN_MSG_NO,
        CHAT_LOGIN_MSG_EN,
        CHAT_GETTING_AUTH_STATUS,
        CHAT_SENDING_AUTH_REQUEST
    };
    @api loggingEnabled; //Determines if console logging is enabled for the component
    @api recordId;
    @api objectApiName;
    @api accountFields; //Comma separated string with field names to display from the related account
    @api caseFields; //Comma separated string with field names to display from the related case
    @api personFields; //Comma separated string with field names to display from the related accounts person
    @api copyPersonFields; //Comma separated string with field numbers to activate copy button

    accountId; //Transcript AccountId
    caseId; //Transcript CaseId
    personId; //Transcript Account PersonId
    currentAuthenticationStatus; //Current auth status of the chat transcript
    sendingAuthRequest = false; //Switch used to show spinner when initiatiing auth process
    activeConversation; //Boolean to determine if the componenet is rendered in a context on an active chat conversation
    chatLanguage;
    chatAuthUrl;
    subscription = {}; //Unique empAPI subscription for the component instance
    loginEvtSent = false;
    nmbOfSecurityMeasures = 0;
    isNavEmployee = false;
    isConfidential = false;

    //#### GETTERS ####

    get isLoading() {
        return !this.currentAuthenticationStatus;
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

    //#### /GETTERS ###

    connectedCallback() {
        this.getAuthUrl();
        //Registering an error listener for handling empApi errors and potential reconnect
        this.registerErrorListener();
        publishToAmplitude('Chat Transcript Opened');
    }

    registerErrorListener() {
        // Invoke onError empApi method
        onError((error) => {
            console.log('Received error from empApi: ', JSON.stringify(error));
            //Try to resubscribe if an error was caught
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
            this.accountId = data.ACCOUNTID;
            this.caseId = data.CASEID;
            this.personId = data.PERSONID;
            this.chatLanguage = data.CHAT_LANGUAGE;

            this.nmbOfSecurityMeasures = parseInt(data.NMB_SECURITY_MEASURES, 10);
            // eslint-disable-next-line eqeqeq
            this.isNavEmployee = 'true' == data.IS_NAV_EMPLOYEE;
            // eslint-disable-next-line eqeqeq
            this.isConfidential = 'true' == data.IS_CONFIDENTIAL;

            //If the authentication is not completed, subscribe to the push topic to receive events
            if (this.currentAuthenticationStatus !== 'Completed' && !this.isLoading && !this.isEmpSubscribed) {
                this.handleSubscribe();
            }
        } else {
            this.currentAuthenticationStatus = 'Not Started';
            this.log(error);
        }
    }

    //Calls apex to get the correct community url for the given sandbox
    getAuthUrl() {
        getCommunityAuthUrl({})
            .then((url) => {
                this.chatAuthUrl = url;
            })
            .catch((error) => {
                console.log('Failed to retrieve auth url: ' + JSON.stringify(error, null, 2));
            });
    }

    //Handles subscription to streaming API for listening to changes to auth status
    handleSubscribe() {
        let _this = this;
        // Callback invoked whenever a new event message is received
        const messageCallback = function (response) {
            console.log('AUTH STATUS UPDATED');
            //Only overwrite status if the event received belongs to this record
            const eventRecordId = response.data.sobject.Id;
            if (eventRecordId === _this.recordId) {
                _this.currentAuthenticationStatus = response.data.sobject.CRM_Authentication_Status__c;
                //If authentication now is complete, get the account id
                if (_this.authenticationComplete) {
                    _this.accountId = response.data.sobject.AccountId;
                    if (!_this.loginEvtSent) _this.sendLoginEvent();
                    getRecordNotifyChange([{ recordId: _this.recordId }]); //Triggers refresh of standard components
                    _this.handleUnsubscribe();
                }
            }
        };

        // Invoke subscribe method of empApi. Pass reference to messageCallback
        //Removed subscription to record specific channel as there are issues when loading multiple components and subscribing
        //to record specific channels on initialization. New solution verifies Id in messageCallback
        subscribe('/topic/Chat_Auth_Status_Changed' /*?Id=" + this.recordId*/, -1, messageCallback).then((response) => {
            // Response contains the subscription information on successful subscribe call
            this.subscription = response;
            console.log('Successfully subscribed to : ', JSON.stringify(response.channel));
        });
    }

    handleUnsubscribe() {
        // Invoke unsubscribe method to not receive duplicate messages for this context
        unsubscribe(this.subscription, (response) => {
            console.log('Unsubscribed: ', JSON.stringify(response));
            // Response is true for successful unsubscribe
        })
            .then(() => {
                //Successfull unsubscribe
                this.log('Successful unsubscribe');
            })
            .catch((error) => {
                console.log('EMP unsubscribe failed: ' + JSON.stringify(error, null, 2));
            });
    }

    sendLoginEvent() {
        getCounselorName({ recordId: this.recordId })
            .then((data) => {
                //Message defaults to norwegian
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

                //Sending event handled by parent to to trigger default chat login message
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

    //Sends event handled by parent to utilize conversation API to send message for init of auth process
    requestAuthentication() {
        this.sendingAuthRequest = true;
        const authUrl = this.chatAuthUrl;

        //Pass the chat auth url
        const requestAuthenticationEvent = new CustomEvent('requestauthentication', {
            detail: { authUrl }
        });
        this.dispatchEvent(requestAuthenticationEvent);
    }

    //Call from aura parent after a successful message to init auth process
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

    //Displays an error toast message if there was any issue in initialiizing authentication
    showAuthError() {
        const event = new ShowToastEvent({
            title: 'Authentication error',
            message: AUTH_INIT_FAILED,
            variant: 'error',
            mode: 'sticky'
        });
        this.dispatchEvent(event);
    }

    //Logger function
    log(loggable) {
        if (this.loggingEnabled) console.log(loggable);
    }
}
