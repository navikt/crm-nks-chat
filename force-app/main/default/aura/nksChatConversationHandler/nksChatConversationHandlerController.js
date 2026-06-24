({
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
    },

    handleChatEnded: function (component, event, helper) {
        const type = event.getParam('type');
        if (type === 'sessionEnded') {
            const eventRecordId = event.getParam('recordId');
            const workspace = component.find('workspace');

            workspace
                .getAllTabInfo()
                .then((tabInfoList) => {
                    const eventTab = tabInfoList.find((tab) => tab.recordId === eventRecordId);
                    if (!eventTab) return;
                    helper.setTabColor(workspace, eventTab.tabId);
                })
                .catch((error) => {
                    console.error('Error retrieving tab info for setting color:', error);
                });
        }
    }
});
