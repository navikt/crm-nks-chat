({
    // Called when the component loads
    onInit: function (component, event, helper) {
        const empApi = component.find('empApi');

        // Register error listener
        empApi.onError(
            $A.getCallback((error) => {
                console.error('EMP API error:', JSON.stringify(error));
            })
        );

        // Subscribe to EMP API events
        helper.subscribeEmpApi(component);
    },

    // Handles event from LWC to initiate authentication using the conversation toolkit API
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
                    });
            } else if (state === 'ERROR') {
                const errors = response.getError();
                if (errors && errors[0] && errors[0].message) {
                    console.error('Error message:', errors[0].message);
                } else {
                    console.error('Unknown error occurred');
                }
            }
        });

        $A.enqueueAction(action);
    },

    handleAuthCompleted: function (component, event, helper) {
        if (component.get('v.authCompletedHandled')) {
            return;
        }

        component.set('v.authCompletedHandled', true);
        helper.showLoginMsg(component, event);
    },

    handleChatEnded: function (component, event, helper) {
        const eventFullId = helper.convertId15To18(event.getParam('recordId'));
        const recordId = component.get('v.recordId');

        if (eventFullId === recordId) {
            const authInfoCmp = component.find('chatAuthInfo');
            authInfoCmp.set('v.chatEnded', true);

            component.set('v.authCompletedHandled', false); // Reset for future chats
        }
    }
});
