global with sharing class NKS_MessagingSessionHandler extends MyTriggers {
    private static LoggerUtility logger = new LoggerUtility('Messaging');

    global override void onAfterUpdate(Map<Id, sObject> triggerOldMap) {
        List<String> fieldNamesToCheck = new List<String>{ 'EndTime', 'Status', 'CRM_Authentication_Status__c' };
        List<MessagingSession> messagingSessionsToConvert = new List<MessagingSession>();

        for (MessagingSession newRecord : (List<MessagingSession>) records) {
            MessagingSession oldRecord = (MessagingSession) triggerOldMap.get(newRecord.Id);
            if (
                MyTriggers.hasChangedFields(fieldNamesToCheck, newRecord, oldRecord) &&
                newRecord.EndTime <= Datetime.now() &&
                newRecord.CRM_Authentication_Status__c == 'Completed' &&
                (newRecord.Status == 'Ended' ||
                newRecord.Status == 'Inactive')
            ) {
                messagingSessionsToConvert.add(newRecord);
            }
        }

        if (messagingSessionsToConvert.size() > 0) {
            System.enqueueJob(
                new NKS_ConversationEntryQueueable(messagingSessionsToConvert, null, null, 'FromStart', 1000)
            );
        }
    }
}
