({
    showLoginMsg: function (component, event) {
        const chatToolkit = component.find('chatToolkit');
        const recordId = component.get('v.recordId');
        const loginMsg = event.getParam('loginMessage');

        chatToolkit
            .sendMessage({
                recordId: recordId,
                message: {
                    text: loginMsg
                }
            })
            .then(function () {});
    },

    setTabIcon: function (component, newTabId, iconName, iconAlt) {
        let workspace = component.find('workspace');
        workspace.setTabIcon({
            tabId: newTabId,
            icon: iconName,
            iconAlt: iconAlt
        });
    },

    subscribeEmpApi: function (component) {
        const empApi = component.find('empApi');
        const channel = '/topic/Chat_Auth_Status_Changed';
        const replayId = -1;

        empApi
            .subscribe(
                channel,
                replayId,
                $A.getCallback((eventReceived) => {
                    this.onEmpApiEvent(component, eventReceived);
                })
            )
            .then((subscription) => {
                component.set('v.subscription', subscription);
            });
    },

    unsubscribeEmpApi: function (component) {
        const empApi = component.find('empApi');
        const subscription = component.get('v.subscription');

        empApi.unsubscribe(
            subscription,
            $A.getCallback(() => {
                component.set('v.subscription', null);
            })
        );
    },

    onEmpApiEvent: function (component, eventReceived) {
        const authStatus = eventReceived.data.sobject.CRM_Authentication_Status__c;
        const changedRecordId = eventReceived.data.sobject.Id;
        const recordId = component.get('v.recordId');

        if (changedRecordId === recordId) {
            component
                .find('workspace')
                .getEnclosingTabId()
                .then((tabId) => {
                    if (authStatus === 'Completed') {
                        this.setTabIcon(component, tabId, 'utility:lock', 'Innlogget chat');
                    } else {
                        this.setTabIcon(component, tabId, 'standard:live_chat', 'Uinnlogget chat');
                    }
                });
        }
    }
});
