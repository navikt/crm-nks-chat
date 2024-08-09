({
    onInit: function (component, event, helper) {
        const empApi = component.find('empApi');
        empApi.onError(
            $A.getCallback((error) => {
                console.error('EMP API error: ', JSON.stringify(error));
            })
        );
        helper.subscribeEmpApi(component);
    },

    requestAuthentication: function (component, event) {
        const chatToolkit = component.find('chatToolkit');
        const recordId = component.get('v.recordId');
        const authInfoCmp = component.find('chatAuthInfo');
        let authUrl = event.getParam('authUrl');

        const action = component.get('c.generateAuthMessage');
        action.setParams({ recordId });
        action.setCallback(this, function (response) {
            const state = response.getState();
            if (state === 'SUCCESS') {
                chatToolkit
                    .sendMessage({
                        recordId: recordId,
                        message: {
                            text: response.getReturnValue() + authUrl + recordId
                        }
                    })
                    .then(function (result) {
                        authInfoCmp.authRequestHandling(result);
                    });
            } else if (state === 'INCOMPLETE') {
                // do something
            } else if (state === 'ERROR') {
                const errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log('Error message: ' + errors[0].message);
                    }
                } else {
                    console.log('Unknown error');
                }
            }
        });
        $A.enqueueAction(action);
    },

    handleAuthCompleted: function (component, event, helper) {
        helper.showLoginMsg(component, event);
    }
});
