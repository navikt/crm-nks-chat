public with sharing class NKS_DeleteConvDataApiBatch implements Database.Batchable<sObject>, Schedulable {
    private static final String QUERY = 'SELECT Id, MessagingEndUserId FROM MessagingSession WHERE EndUserAccountId = NULL AND CRM_Authentication_Status__c != \'Completed\' AND Status IN (\'Ended\', \'Inactive\', \'Error\') AND CreatedDate <= N_DAYS_AGO:2';

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator(QUERY);
    }

    public void execute(Database.BatchableContext context, List<MessagingSession> scope) {
        Set<Id> sessionIds = new Set<Id>();
        for (MessagingSession session : scope) {
            sessionIds.add(session.Id);
        }

        // Since we delete unauthenticated Messaging Sessions (with the chat content), we need to copy the other data to ReportingData__c before deletion for statistics.
        // Sessions that already have reporting data have already had their deletion enqueued, so skip them here.
        Set<Id> sessionIdsToDelete = NKS_MessagingSessionReportData.copyToReportingData(sessionIds);

        List<String> participantEntityIds = new List<String>(); // Limit of 50 in API
        for (MessagingSession session : scope) {
            if (sessionIdsToDelete.contains(session.Id) && session.MessagingEndUserId != null) {
                participantEntityIds.add(session.MessagingEndUserId);
            }
        }

        NKS_ConversationEntryController.deleteSessionDataAndEnqueueCallout(sessionIdsToDelete, participantEntityIds);
    }

    public void finish(Database.BatchableContext context) {
    }

    // Should run every hour. Cron exp: 0 0 * * * ?
    public void execute(SchedulableContext context) {
        Database.executeBatch(new NKS_DeleteConvDataApiBatch(), 40);
    }
}
