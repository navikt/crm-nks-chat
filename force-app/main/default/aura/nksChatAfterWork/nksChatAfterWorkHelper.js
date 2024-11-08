({
    startTimer: function (component, event) {
        if (component.get('v.showTimer')) return;

        component.set('v.showTimer', true);
        component.set('v.maxTimer', component.get('v.timer'));

        // eslint-disable-next-line @lwc/lwc/no-async-operation, @locker/locker/distorted-window-set-interval
        const intervalId = setInterval(() => {
            if (component.get('v.stopped')) {
                clearInterval(intervalId);
                return;
            }

            let timer = component.get('v.timer') - 1;
            const maxTimer = component.get('v.maxTimer');
            component.set('v.timer', timer);
            component.set('v.percentageTimer', (timer * 100) / maxTimer);

            if (timer <= 0) {
                clearInterval(intervalId);
                this.closeTab(component, event);
            }
        }, 1000);
    },

    closeTab: function (component, eventRecordId) {
        const workspaceAPI = component.find('workspace');
        if (!workspaceAPI) {
            console.warn('Workspace API not found.');
            return;
        }

        workspaceAPI
            .getAllTabInfo()
            .then((tabInfo) => {
                const eventTab = tabInfo.find((tab) => tab.recordId === eventRecordId);
                if (eventTab) {
                    workspaceAPI.closeTab({ tabId: eventTab.tabId });
                }
            })
            .catch((error) => {
                console.error('Error closing tab:', error);
            });
    },

    convertId15To18: function (Id) {
        if (Id.length !== 15) return Id;

        let addon = '';
        for (let block = 0; block < 3; block++) {
            let bitPattern = 0;
            for (let position = 0; position < 5; position++) {
                const char = Id.charAt(block * 5 + position);
                if (char >= 'A' && char <= 'Z') {
                    bitPattern += 1 << position;
                }
            }
            addon += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ012345'.charAt(bitPattern);
        }
        return Id + addon;
    }
});
