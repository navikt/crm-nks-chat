({
    setTabLabelAndIcon: function (component, tabId, recordId) {
        const workspace = component.find('workspace');
        const action = component.get('c.getMessagingSession');
        action.setParams({ recordId: recordId });

        action.setCallback(this, function (response) {
            const sessionInfo = response.getReturnValue();
            if (sessionInfo) {
                if (sessionInfo.Queue_Name__c) {
                    const queueName = sessionInfo.Queue_Name__c.split('_').pop();
                    const tabNumber = sessionInfo.Name ? sessionInfo.Name.slice(-2) : '';
                    const label = `Chat ${queueName} ${tabNumber}`;
                    workspace.setTabLabel({ tabId: tabId, label: label });
                }
            }
        });

        $A.enqueueAction(action);
    }
});
