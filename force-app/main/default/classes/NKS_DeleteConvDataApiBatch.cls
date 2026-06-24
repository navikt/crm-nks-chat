public with sharing class NKS_DeleteConvDataApiBatch implements Database.Batchable<sObject>, Schedulable {
    private static final String QUERY = 'SELECT Id, MessagingEndUserId FROM MessagingSession WHERE EndUserAccountId = NULL AND CRM_Authentication_Status__c != \'Completed\' AND Status IN (\'Ended\', \'Inactive\', \'Error\') AND ((Queue_Name__c IN (\'NKS_Messaging_Gjeldsraadgivning\', \'NKS_Messaging_Sosiale_Tjenester\') AND CreatedDate = LAST_N_DAYS:2) OR (Queue_Name__c NOT IN (\'NKS_Messaging_Gjeldsraadgivning\', \'NKS_Messaging_Sosiale_Tjenester\') AND CreatedDate <= N_DAYS_AGO:2))';

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator(QUERY);
    }

    public void execute(Database.BatchableContext context, List<MessagingSession> scope) {
        Set<Id> sessionIds = new Set<Id>();
        List<String> participantEntityIds = new List<String>(); // Limit of 50 in API
        for (MessagingSession session : scope) {
            sessionIds.add(session.Id);
            if (session.MessagingEndUserId != null) {
                participantEntityIds.add(session.MessagingEndUserId);
            }
        }

        NKS_ConversationEntryController.deleteSessionDataAndEnqueueCallout(sessionIds, participantEntityIds);
    }

    public void finish(Database.BatchableContext context) {
    }

    // Should run every hour. Cron exp: 0 0 * * * ?
    public void execute(SchedulableContext context) {
        Database.executeBatch(new NKS_DeleteConvDataApiBatch(), 50);
    }
}
