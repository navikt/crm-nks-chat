public with sharing class NKS_ReportingDataDeleteBatch implements Database.Batchable<sObject>, Schedulable {
    // NKS_Messaging_Session__c is a long text area and cannot be filtered directly, so NKS_Has_Messaging_Session__c is used instead
    private static final String QUERY = 'SELECT Id FROM ReportingData__c WHERE CRM_Category__c = \'Chat\' AND NKS_Has_Messaging_Session__c = true AND CreatedDate <= N_DAYS_AGO:365';

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator(QUERY);
    }

    public void execute(Database.BatchableContext context, List<ReportingData__c> scope) {
        delete scope;
    }

    public void finish(Database.BatchableContext context) {
    }

    // Should run once a day. Cron exp: 0 0 0 * * ?
    public void execute(SchedulableContext context) {
        Database.executeBatch(new NKS_ReportingDataDeleteBatch(), 100);
    }
}
