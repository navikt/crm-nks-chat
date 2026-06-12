({
    handleChatEnded: function (component, event, helper) {
        const recordId = component.get('v.recordId');
        const eventRecordId = event.getParam('recordId');

        if (recordId !== eventRecordId) {
            return;
        }

        helper.startTimer(component, eventRecordId);

        const sessionEnded = $A.get('e.c:afterworkEvent');
        sessionEnded.setParams({
            recordId: eventRecordId,
            type: 'sessionEnded'
        });
        sessionEnded.fire();
    },

    stopTimer: function (component) {
        component.set('v.stopped', true);

        const action = component.get('c.reportThreatClick');
        action.setCallback(this, function (response) {
            const responseState = response.getState();

            if (responseState === 'SUCCESS') {
                const reportingId = response.getReturnValue();
                const recordId = component.get('v.recordId');

                const appEvent = $A.get('e.c:afterworkEvent');
                appEvent.setParams({
                    reportingId: reportingId,
                    recordId: recordId,
                    type: 'createdThreatReport'
                });
                appEvent.fire();
            } else if (responseState === 'INCOMPLETE') {
                console.warn('Action incomplete: No response from server.');
            } else if (responseState === 'ERROR') {
                const errors = response.getError();
                if (errors && errors[0] && errors[0].message) {
                    console.error('Error message:', errors[0].message);
                } else {
                    console.error('Unknown error');
                }
            }
        });

        $A.enqueueAction(action);
    }
});
