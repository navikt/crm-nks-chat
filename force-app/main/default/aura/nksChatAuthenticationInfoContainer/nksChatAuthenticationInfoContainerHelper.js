({
    convertId15To18: function (Id) {
        if (Id.length === 15) {
            var addon = '';
            for (var block = 0; block < 3; block++) {
                var loop = 0;
                for (var position = 0; position < 5; position++) {
                    var current = Id.charAt(block * 5 + position);
                    if (current >= 'A' && current <= 'Z') loop += 1 << position;
                }
                addon += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ012345'.charAt(loop);
            }
            return Id + addon;
        }
        return Id;
    },

    showLoginMsg: function (component, event) {
        const chatToolkit = component.find('chatToolkit');
        const recordId = component.get('v.recordId');
        const loginMsg = event.getParam('loginMessage');

        chatToolkit
            .sendMessage({
                recordId,
                message: { text: loginMsg }
            })
            .then(() => {
                console.log('Login message sent successfully');
            })
            .catch((error) => {
                console.error('Error sending login message:', JSON.stringify(error));
            });
    },

    updateTabIconForAuthStatus: function (component, authStatus) {
        const workspace = component.find('workspace');

        workspace
            .getEnclosingTabId()
            .then((tabId) => {
                if (authStatus === 'Completed') {
                    return workspace.setTabIcon({
                        tabId,
                        icon: 'utility:lock',
                        iconAlt: 'Innlogget chat'
                    });
                }

                return workspace.setTabIcon({
                    tabId,
                    icon: 'standard:live_chat',
                    iconAlt: 'Uinnlogget chat'
                });
            })
            .catch((e) => {
                console.error('Failed to set tab icon:', JSON.stringify(e));
            });
    }
});
