({
    storeClosedChatTabId: function (component, tabId, recordId) {
        const closedChatList = component.get('v.closedChatList') || [];
        closedChatList.push({ tab: tabId, recordId: recordId });
        component.set('v.closedChatList', closedChatList);
    },

    removeClosedChatTabId: function (component, tabId) {
        let closedChatList = component.get('v.closedChatList') || [];
        const index = closedChatList.findIndex((tab) => tab.tab === tabId);
        if (index === -1) return;

        const recordId = closedChatList[index].recordId;
        closedChatList = closedChatList.filter((tab) => tab.tab !== tabId);
        component.set('v.closedChatList', closedChatList);

        this.removeThreatReport(component, recordId);
    },

    storeThreatReport: function (component, reportingId, recordId) {
        const threatReportList = component.get('v.threatReportList') || [];
        threatReportList.push({ reportingId: reportingId, recordId: recordId, time: Date.now() });
        component.set('v.threatReportList', threatReportList);
    },

    removeThreatReport: function (component, recordId) {
        let threatReportList = component.get('v.threatReportList') || [];
        const index = threatReportList.findIndex((reporting) => reporting.recordId === recordId);
        if (index === -1) return;

        const reportingId = threatReportList[index].reportingId;
        const time = Date.now() - threatReportList[index].time;
        threatReportList = threatReportList.filter((reporting) => reporting.recordId !== recordId);
        component.set('v.threatReportList', threatReportList);

        this.updateThreatTime(component, reportingId, time);
    },

    updateThreatTime: function (component, reportingId, time) {
        const action = component.get('c.updateThreatClickValue');
        action.setParams({ rDataId: reportingId, value: time });

        action.setCallback(this, function (response) {
            const state = response.getState();
            if (state !== 'SUCCESS') {
                console.error('Error updating threat time:', response.getError());
            }
        });

        $A.enqueueAction(action);
    }
});
