public with sharing class NKS_ReportingDataDeleteBatch implements Database.Batchable<sObject>, Schedulable {
    private static final String QUERY = 'SELECT Id, NKS_Messaging_Session__c FROM ReportingData__c WHERE CRM_Category__c = \'Chat\' AND CreatedDate <= N_DAYS_AGO:365';

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator(QUERY);
    }

    public void execute(Database.BatchableContext context, List<ReportingData__c> scope) {
        List<ReportingData__c> toDelete = new List<ReportingData__c>();
        for (ReportingData__c report : scope) {
            // Long text area field cannot be used in a WHERE filter, so check it here
            if (!String.isBlank(report.NKS_Messaging_Session__c)) {
                toDelete.add(report);
            }
        }
        delete toDelete;
    }

    public void finish(Database.BatchableContext context) {
    }

    // Should run once a day. Cron exp: 0 0 0 * * ?
    public void execute(SchedulableContext context) {
        Database.executeBatch(new NKS_ReportingDataDeleteBatch(), 100);
    }
}
