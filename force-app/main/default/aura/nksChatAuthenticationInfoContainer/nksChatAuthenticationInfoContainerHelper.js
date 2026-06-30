({
    convertId15To18: function (id) {
        if (id.length !== 15) {
            return id;
        }

        let addon = '';

        for (let block = 0; block < 3; block++) {
            let loop = 0;

            for (let position = 0; position < 5; position++) {
                const current = id.charAt(block * 5 + position);
                if (current >= 'A' && current <= 'Z') {
                    loop += 1 << position;
                }
            }

            addon += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ012345'.charAt(loop);
        }

        return id + addon;
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

    updateTabForAuthStatus: function (component, authStatus) {
        const workspace = component.find('workspace');

        workspace
            .getEnclosingTabId()
            .then((tabId) => {
                component.set('v.chatTabId', tabId);

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
            .catch((error) => {
                console.error('Failed to update tab for auth status:', JSON.stringify(error));
            });
    },

    setSuccessTabState: function (component) {
        this.setTabStateWithDelay(component, 'success');
    },

    setEndedTabState: function (component) {
        this.setTabStateWithDelay(component, 'error');
    },

    setTabStateWithDelay: function (component, state) {
        const workspace = component.find('workspace');
        const tabId = component.get('v.chatTabId');

        if (!tabId) {
            return;
        }

        // eslint-disable-next-line @lwc/lwc/no-async-operation, @locker/locker/distorted-window-set-timeout
        window.setTimeout(
            $A.getCallback(() => {
                workspace
                    .setTabHighlighted({
                        tabId,
                        highlighted: true,
                        options: { state }
                    })
                    .catch((error) => {
                        console.error('Failed to set tab state:', JSON.stringify(error));
                    });
            }),
            500
        );
    }
});
