import { LightningElement, api, wire } from 'lwc';
import getThreadId from '@salesforce/apex/nksChatView.getThreadId';
import markasread from '@salesforce/apex/CRM_MessageHelperExperience.markAsRead';
import getChatbotMessage from '@salesforce/apex/nksChatView.getChatbotMessage';
import { publish, MessageContext } from 'lightning/messageService';
import globalModalOpen from '@salesforce/messageChannel/globalModalOpen__c';
import userId from '@salesforce/user/Id';
import getmessages from '@salesforce/apex/CRM_MessageHelperExperience.getMessagesFromThread';
import getContactId from '@salesforce/apex/CRM_MessageHelperExperience.getUserContactId';
import {logModalEvent} from 'c/amplitude';

export default class NksChatView extends LightningElement {
    @api recordId;

    threadId;
    errorList = { title: '', errors: [] };
    modalOpen = false;
    chatbotMessage = 'Laster inn samtale';
    userContactId;
    messages;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        getContactId({})
            .then((contactId) => {
                this.userContactId = contactId;
            })
            .catch(() => {
                //Apex error
            });
    }

    @wire(getThreadId, { chatId: '$recordId' })
    test({ error, data }) {
        if (error) {
            console.log(error);
        }
        if (data) {
            this.threadId = data;
            markasread({ threadId: this.threadId });
        }
    }

    @wire(getmessages, { threadId: '$threadId' }) //Calls apex and extracts messages related to this record
    wiremessages(result) {
        if (result.error) {
            this.error = result.error;
        } else if (result.data) {
            this.messages = result.data;
        }
    }

    handleValidation() {
        this.errorList = {
            title: '',
            errors: [{ Id: 1, EventItem: '', Text: 'Du kan ikke sende melding på en chat.' }]
        };
        this.createMessage(false);
    }

    createMessage(validation) {
        this.template.querySelector('c-crm-messaging-community-thread-viewer').createMessage(validation);
    }

    handleModalButton() {
        this.modalOpen = true;
        this.termsModal.focusModal();
        publish(this.messageContext, globalModalOpen, { status: 'true' });
        getChatbotMessage({ chatId: this.recordId, userId: userId }).then((res) => {
            this.chatbotMessage = res;
        });

        logModalEvent(true, 'Chatbot samtale', 'nksChatView', 'Chatsamtale' );
    }

    closeModal() {
        this.modalOpen = false;
        publish(this.messageContext, globalModalOpen, { status: 'false' });
        const btn = this.template.querySelector('.focusBtn');
        btn.focus();

        logModalEvent(false, 'Chatbot samtale', 'nksChatView', 'Chatsamtale' );
    }

    handleKeyboardEvent(event) {
        if (event.keyCode === 27 || event.code === 'Escape') {
            this.closeModal();
        } else if (event.keyCode === 9 || event.code === 'Tab') {
            this.termsModal.focusLoop();
        }
    }

    get termsModal() {
        return this.template.querySelector('c-community-modal');
    }
}
