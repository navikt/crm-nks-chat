public with sharing class NKS_DeleteConvDataApiBatch implements Database.Batchable<sObject>, Schedulable {
    private static final String QUERY = 'SELECT Id, MessagingEndUserId FROM MessagingSession WHERE CreatedDate = TODAY AND EndUserAccountId = NULL AND CRM_Authentication_Status__c != \'Completed\' AND (Status IN (\'Ended\', \'Inactive\')) AND Queue_Name__c IN (\'NKS_Messaging_Gjeldsraadgivning\', \'NKS_Messaging_Sosiale_Tjenester\')';

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator(QUERY);
    }

    public void execute(Database.BatchableContext context, List<MessagingSession> scope) {
        List<String> participantEntityIds = new List<String>(); // Limit of 50 in API
        for (MessagingSession session : scope) {
            if (session.MessagingEndUserId != null) {
                participantEntityIds.add(session.MessagingEndUserId);
            }
        }
        if (!participantEntityIds.isEmpty()) {
            NKS_ConversationEntryService.deleteConversationParticipantData(participantEntityIds);
        }
    }

    public void finish(Database.BatchableContext context) {
    }

    // Should run every hour. Cron exp: 0 0 * * * ?
    public void execute(SchedulableContext context) {
        Database.executeBatch(new NKS_DeleteConvDataApiBatch());
    }
}
