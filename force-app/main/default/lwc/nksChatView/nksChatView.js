import { LightningElement, api, wire } from 'lwc';
import getThread from '@salesforce/apex/nksChatView.getThread';
import markasread from '@salesforce/apex/CRM_MessageHelperExperience.markAsRead';
import getChatbotMessage from '@salesforce/apex/nksChatView.getChatbotMessage';
import { publish, MessageContext } from 'lightning/messageService';
import globalModalOpen from '@salesforce/messageChannel/globalModalOpen__c';
import userId from '@salesforce/user/Id';
import getGroupedMessagesFromThread from '@salesforce/apex/CRM_MessageHelperExperience.getGroupedMessagesFromThread';
import getContactId from '@salesforce/apex/CRM_MessageHelperExperience.getUserContactId';
import { logModalEvent, setDecoratorParams, getComponentName } from 'c/inboxAmplitude';

export default class NksChatView extends LightningElement {
    @api recordId;

    threadId;
    errorList = { title: '', errors: [] };
    modalOpen = false;
    chatbotMessage = 'Laster inn samtale';
    userContactId;
    messageGroups;
    themeGroup;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        getContactId({})
            .then((contactId) => {
                this.userContactId = contactId;
            })
            .catch((error) => {
                console.error('Error retrieving contactId: ', error);
            });
    }

    @wire(getThread, { chatId: '$recordId' })
    wiredThread(result) {
        const { error, data } = result;
        if (error) {
            console.error(error);
        }
        if (data) {
            this.threadId = data.Id;
            markasread({ threadId: this.threadId });

            this.themeGroup = data.CRM_Theme_Group_Name__c;
            if (this.themeGroup) {
                setDecoratorParams('Chat', `Chatsamtale - ${this.themeGroup}`, this.themeGroup);
            }
        }
    }

    @wire(getGroupedMessagesFromThread, { threadId: '$threadId' })
    wiredGroups(result) {
        const { data, error } = result;
        if (error) {
            console.error(error);
        } else if (data) {
            this.messageGroups = data;
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

    async handleModalButton() {
        this.modalOpen = true;
        publish(this.messageContext, globalModalOpen, { status: 'true' });
        this.chatbotMessage = 'Laster inn samtale';
        try {
            this.chatbotMessage = await getChatbotMessage({ chatId: this.recordId, userId: userId });
        } catch (e) {
            this.chatbotMessage = 'Kunne ikke laste samtale';
        }
        logModalEvent(true, 'Chatbot samtale', getComponentName(this.template), 'Chatsamtale');
    }

    closeModal() {
        this.modalOpen = false;
        publish(this.messageContext, globalModalOpen, { status: 'false' });
        const btn = this.template.querySelector('.frida-button');
        if (btn) btn.focus();
        logModalEvent(false, 'Chatbot samtale', getComponentName(this.template), 'Chatsamtale');
    }
}
