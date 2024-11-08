({
    handleChatEnded: function (component, event, helper) {
        const type = event.getParam('type');
        if (type === 'sessionEnded') {
            const chatToolkit = component.find('chatToolkit');
            const eventRecordId = event.getParam('recordId');
            const workspace = component.find('workspace');
            const eventFullID = helper.convertId15To18(eventRecordId);

            workspace
                .getAllTabInfo()
                .then((res) => {
                    const eventTab = res.find((content) => content.recordId === eventFullID);
                    if (!eventTab) return;
                    helper.setTabColor(workspace, eventTab.tabId, 'success');
                })
                .catch((error) => {
                    console.error('Error: ', error);
                });

            chatToolkit
                .getChatLog({
                    recordId: eventRecordId
                })
                .then((result) => {
                    let conversation = result.messages;
                    let filteredConversation = conversation.filter(function (message) {
                        //Filtering out all messages of type supervisor and AgentWhisper as these are "whispers" and should not be added to the journal
                        return message.type !== 'Supervisor' && message.type !== 'AgentWhisper';
                    });
                    helper.callStoreConversation(component, filteredConversation, eventRecordId);
                })
                .catch((error) => {
                    console.error('Error: ', error);
                });
        }
    },

    onTabCreated: function (component, event, helper) {
        const newTabId = event.getParam('tabId');
        const workspace = component.find('workspace');

        workspace.getAllTabInfo().then(function (response) {
            if (response.length === 1) {
                workspace
                    .isSubtab({
                        tabId: newTabId
                    })
                    .then(function (response2) {
                        if (!response2) {
                            workspace.focusTab({
                                tabId: newTabId
                            });
                        }
                    });
            }
        });

        workspace
            .getTabInfo({
                tabId: newTabId
            })
            .then(function (response) {
                helper.setTabLabelAndIcon(component, newTabId, response.recordId);
            });
    }
});
