global with sharing class NKS_MessagingSessionHandler extends MyTriggers {
    private static LoggerUtility logger = new LoggerUtility('Messaging');
    private static final String LOG_PREFIX = 'NKS_MessagingSessionHandler';

    global override void onAfterUpdate(Map<Id, sObject> triggerOldMap) {
        List<Id> messagingSessionIdsToConvert = new List<Id>();

        logger.info(
            LOG_PREFIX +
                '.onAfterUpdate START | records.size=' +
                (((List<MessagingSession>) records) == null ? 0 : ((List<MessagingSession>) records).size()),
            null,
            CRM_ApplicationDomain.Domain.NKS
        );

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

                logger.info(
                    LOG_PREFIX +
                        '.onAfterUpdate | sessionId=' +
                        newRecord.Id +
                        ' | oldEndTime=' +
                        String.valueOf(oldRecord.EndTime) +
                        ' | newEndTime=' +
                        String.valueOf(newRecord.EndTime) +
                        ' | oldStatus=' +
                        oldRecord.Status +
                        ' | newStatus=' +
                        newRecord.Status +
                        ' | oldAuthStatus=' +
                        oldRecord.CRM_Authentication_Status__c +
                        ' | newAuthStatus=' +
                        newRecord.CRM_Authentication_Status__c +
                        ' | relevantFieldChanged=' +
                        relevantFieldChanged +
                        ' | shouldConvert=' +
                        shouldConvert,
                    null,
                    CRM_ApplicationDomain.Domain.NKS
                );

                if (shouldConvert) {
                    messagingSessionIdsToConvert.add(newRecord.Id);
                }
            }

            logger.info(
                LOG_PREFIX +
                    '.onAfterUpdate | messagingSessionIdsToConvert=' +
                    JSON.serialize(messagingSessionIdsToConvert),
                null,
                CRM_ApplicationDomain.Domain.NKS
            );

            if (!messagingSessionIdsToConvert.isEmpty()) {
                System.enqueueJob(
                    new NKS_ConversationEntryQueueable(messagingSessionIdsToConvert, null, null, 'FromStart', 1000)
                );

                logger.info(LOG_PREFIX + '.onAfterUpdate | Queueable enqueued', null, CRM_ApplicationDomain.Domain.NKS);
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
