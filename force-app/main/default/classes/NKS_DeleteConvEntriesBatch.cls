public with sharing class NKS_DeleteConvEntriesBatch implements Database.Batchable<sObject>, Schedulable {
    private static final string QUERY = 'SELECT Id FROM ConversationEntry WHERE ConversationId IN (SELECT ConversationId FROM MessagingSession WHERE CreatedDate = TODAY AND EndUserAccountId = NULL AND CRM_Authentication_Status__c != \'Completed\' AND (Status IN (\'Ended\', \'Inactive\')) AND Queue_Name__c IN (\'NKS_Messaging_Gjeldsraadgivning\', \'NKS_Messaging_Sosiale_Tjenester\'))';

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator(QUERY);
    }

    public void execute(Database.BatchableContext context, List<ConversationEntry> scope) {
        delete scope;
    }

    public void finish(Database.BatchableContext context) {
    }

    // Should run every hour. Cron exp: 0 0 * * * ?
    public void execute(SchedulableContext context) {
        Database.executeBatch(new NKS_DeleteConvEntriesBatch());
    }
}
