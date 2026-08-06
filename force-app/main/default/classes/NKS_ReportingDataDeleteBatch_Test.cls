@IsTest
public with sharing class NKS_ReportingDataDeleteBatch_Test {
    @TestSetup
    static void makeData() {
        ReportingData__c oldReport = new ReportingData__c(
            CRM_Category__c = 'Chat',
            NKS_Messaging_Session__c = '{"Status":"Ended"}'
        );
        insert oldReport;
        Test.setCreatedDate(oldReport.Id, Datetime.now().addDays(-400));

        ReportingData__c recentReport = new ReportingData__c(
            CRM_Category__c = 'Chat',
            NKS_Messaging_Session__c = '{"Status":"Ended"}'
        );
        insert recentReport;

        ReportingData__c otherReport = new ReportingData__c(CRM_Category__c = 'Chat Threat');
        insert otherReport;
        Test.setCreatedDate(otherReport.Id, Datetime.now().addDays(-400));
    }

    @IsTest
    static void runBatch_deletesOldMessagingSessionReportingData() {
        Test.startTest();
        Database.executeBatch(new NKS_ReportingDataDeleteBatch());
        Test.stopTest();

        Assert.areEqual(2, [SELECT COUNT() FROM ReportingData__c]);
    }

    @IsTest
    static void testSchedulerExecution() {
        Test.startTest();
        String cron = '0 0 2 * * ?';
        String jobId = System.schedule('Test Reporting Data Delete Batch', cron, new NKS_ReportingDataDeleteBatch());
        Test.stopTest();

        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered FROM CronTrigger WHERE id = :jobId];
        Assert.areEqual(cron, ct.CronExpression, 'Cron expression should match the one used in scheduling');
    }
}
