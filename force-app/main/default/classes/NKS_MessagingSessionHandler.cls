global with sharing class NKS_MessagingSessionHandler extends MyTriggers {
    private static LoggerUtility logger = new LoggerUtility('Messaging');
    private static final String LOG_PREFIX = 'NKS_MessagingSessionHandler';

    global override void onAfterUpdate(Map<Id, sObject> triggerOldMap) {
        try {
            NKS_ConversationEntryQueueable job = buildConversionJob((List<MessagingSession>) records, triggerOldMap);

            if (job != null) {
                System.enqueueJob(job);
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

    @TestVisible
    private static NKS_ConversationEntryQueueable buildConversionJob(
        List<MessagingSession> sessions,
        Map<Id, sObject> oldMap
    ) {
        List<String> watchedFields = new List<String>{ 'EndTime', 'Status', 'CRM_Authentication_Status__c' };
        List<Id> ids = new List<Id>();
        for (MessagingSession session : sessions) {
            MessagingSession oldSession = (MessagingSession) oldMap.get(session.Id);
            if (
                MyTriggers.hasChangedFields(watchedFields, session, oldSession) &&
                session.EndTime != null &&
                session.EndTime <= Datetime.now() &&
                session.CRM_Authentication_Status__c == 'Completed' &&
                (session.Status == 'Ended' ||
                session.Status == 'Inactive')
            ) {
                ids.add(session.Id);
            }
        }
        return ids.isEmpty() ? null : new NKS_ConversationEntryQueueable(ids, null, null, 'FROMSTART', 1000);
    }
}
