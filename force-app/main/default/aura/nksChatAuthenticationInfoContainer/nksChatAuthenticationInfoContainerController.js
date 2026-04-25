({
    onInit: function (component, event, helper) {
        // No EMP API in Aura anymore. LWC owns CDC subscription.
    },

    requestAuthentication: function (component, event) {
        const chatToolkit = component.find('chatToolkit');
        const recordId = component.get('v.recordId');
        const authInfoCmp = component.find('chatAuthInfo');
        const authUrl = event.getParam('authUrl');
        const action = component.get('c.generateAuthMessage');

        action.setParams({ recordId });

        action.setCallback(this, function (response) {
            const state = response.getState();

            if (state === 'SUCCESS') {
                const authMessage = response.getReturnValue() + authUrl + recordId;

                chatToolkit
                    .sendMessage({
                        recordId,
                        message: { text: authMessage }
                    })
                    .then((result) => {
                        authInfoCmp.authRequestHandling(result);
                    })
                    .catch((error) => {
                        console.error('Error sending message:', JSON.stringify(error));
                        authInfoCmp.authRequestHandling(false);
                    });
            } else if (state === 'ERROR') {
                console.error('Apex error:', JSON.stringify(response.getError()));
                authInfoCmp.authRequestHandling(false);
            } else {
                console.error('Unexpected apex state:', state);
                authInfoCmp.authRequestHandling(false);
            }
        });

        $A.enqueueAction(action);
    },

    handleAuthCompleted: function (component, event, helper) {
        if (component.get('v.authCompletedHandled')) return;

        component.set('v.authCompletedHandled', true);
        helper.showLoginMsg(component, event);
    },

    handleAuthStatusChange: function (component, event, helper) {
        // Fired by LWC whenever auth status changes
        const status = event.getParam('status');
        helper.updateTabIconForAuthStatus(component, status);
    },

    handleChatEnded: function (component, event, helper) {
        const eventFullId = helper.convertId15To18(event.getParam('recordId'));
        const recordId = component.get('v.recordId');

        if (eventFullId === recordId) {
            component.set('v.chatEnded', true);
            component.set('v.authCompletedHandled', false); // reset for future chats
        }
    }
});
