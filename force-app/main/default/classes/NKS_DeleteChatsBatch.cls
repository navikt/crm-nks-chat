public with sharing class NKS_DeleteChatsBatch implements Database.Batchable<sObject>, Schedulable {
    private final String query;

    public NKS_DeleteChatsBatch() {
        this.query = 'SELECT Id FROM ConversationEntry WHERE ConversationId IN (SELECT ConversationId FROM MessagingSession WHERE CreatedDate = TODAY AND EndUserAccountId = NULL AND CRM_Authentication_Status__c != \'Completed\' AND (Status = \'Ended\' OR Status = \'Inactive\') AND (Queue_Name__c = \'NKS_Messaging_Gjeldsraadgivning\' OR Queue_Name__c = \'NKS_Messaging_Sosiale_Tjenester\'))';
    }
    public NKS_DeleteChatsBatch(String query) {
        this.query = query;
    }
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext context, List<ConversationEntry> scope) {
        delete scope;
    }

    public void finish(Database.BatchableContext context) {
    }

    // Should run every hour. Cron exp: 0 0 * * * ?
    public void execute(SchedulableContext context) {
        Database.executeBatch(new NKS_DeleteChatsBatch());
    }
}
