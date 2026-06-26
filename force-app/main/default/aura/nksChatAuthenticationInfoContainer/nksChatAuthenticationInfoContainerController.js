({
    requestAuthentication: function (component, event, helper) {
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
                return;
            }

            if (state === 'ERROR') {
                console.error('Apex error:', JSON.stringify(response.getError()));
            } else {
                console.error('Unexpected apex state:', state);
            }

            authInfoCmp.authRequestHandling(false);
        });

        $A.enqueueAction(action);
    },

    handleAuthCompleted: function (component, event, helper) {
        if (component.get('v.authCompletedHandled')) {
            return;
        }

        component.set('v.authCompletedHandled', true);
        helper.showLoginMsg(component, event);
        helper.setSuccessTabState(component);
    },

    handleAuthStatusChange: function (component, event, helper) {
        // Fired by LWC whenever auth status changes
        const status = event.getParam('status');
        helper.updateTabForAuthStatus(component, status);

        if (status === 'Authentication Requested') {
            helper.setWarningTabState(component);
        }
    },

    handleChatEnded: function (component, event, helper) {
        const eventFullId = helper.convertId15To18(event.getParam('recordId'));
        const recordId = component.get('v.recordId');

        if (eventFullId !== recordId) {
            return;
        }

        component.set('v.chatEnded', true);
        component.set('v.authCompletedHandled', false);
        helper.setEndedTabState(component);
    }
});
