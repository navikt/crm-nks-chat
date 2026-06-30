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
    }
});
