global with sharing class NKS_MessagingSessionHandler extends MyTriggers {
    private static LoggerUtility logger = new LoggerUtility('Messaging');
    private static final String LOG_PREFIX = 'NKS_MessagingSessionHandler';

    global override void onAfterUpdate(Map<Id, sObject> triggerOldMap) {
        List<Id> messagingSessionIdsToConvert = new List<Id>();

        try {
            for (MessagingSession newRecord : (List<MessagingSession>) records) {
                MessagingSession oldRecord = (MessagingSession) triggerOldMap.get(newRecord.Id);

                Boolean relevantFieldChanged =
                    newRecord.EndTime != oldRecord.EndTime ||
                    newRecord.Status != oldRecord.Status ||
                    newRecord.CRM_Authentication_Status__c != oldRecord.CRM_Authentication_Status__c;

                Boolean shouldConvert =
                    relevantFieldChanged &&
                    newRecord.EndTime != null &&
                    newRecord.EndTime <= Datetime.now() &&
                    newRecord.CRM_Authentication_Status__c == 'Completed' &&
                    (newRecord.Status == 'Ended' ||
                    newRecord.Status == 'Inactive');

                if (shouldConvert) {
                    messagingSessionIdsToConvert.add(newRecord.Id);
                }
            }

            if (!messagingSessionIdsToConvert.isEmpty()) {
                System.enqueueJob(
                    new NKS_ConversationEntryQueueable(messagingSessionIdsToConvert, null, null, 'FromStart', 1000)
                );
            }
        } catch (Exception e) {
            logger.error(
                LOG_PREFIX +
                    '.onAfterUpdate ERROR' +
                    ' | message=' +
                    e.getMessage() +
                    ' | stack=' +
                    e.getStackTraceString(),
                null,
                CRM_ApplicationDomain.Domain.NKS
            );
        } finally {
            logger.publish();
        }
    }
}
