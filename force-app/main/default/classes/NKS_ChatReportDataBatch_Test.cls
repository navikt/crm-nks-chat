@IsTest
public with sharing class NKS_ChatReportDataBatch_Test {
    @TestSetup
    static void makeData() {
        User testUser = [SELECT Id FROM User LIMIT 1];
        MessagingSession messagingSession1 = new MessagingSession(status = 'Completed');
        MessagingSession messagingSession2 = new MessagingSession(status = 'Completed');
        UTIL_TestDataFactory.createRecordList(new List<MessagingSession>{ messagingSession1, messagingSession2 });
        // transcript.owner = testUser.Id;
        ReportingData__c report = new ReportingData__c(CRM_Category__c = 'Chat', NKS_Related_Record__c = transcript.id);
        insert report;
    }

    @IsTest
    static void runBatch() {
        Test.startTest();
        Database.executeBatch(new NKS_ChatReportDataBatch());
        Test.stopTest();
    }

    @IsTest
    static void runBatchWithCustomQuery() {
        List<ReportingData__c> beforeData = [
            SELECT Id
            FROM ReportingData__c
            WHERE CRM_Category__c = 'Chat'
        ];
        Test.startTest();
        Database.executeBatch(
            new NKS_ChatReportDataBatch(
                'Select Id, Typeof Owner WHEN User THEN Department WHEN Group THEN Name END from MessagingSession where status = \'completed\''
            )
        );
        Test.stopTest();
        List<ReportingData__c> afterData = [
            SELECT Id
            FROM ReportingData__c
            WHERE CRM_Category__c = 'Chat'
        ];
        Assert.areEqual(1, beforeData.size());
        Assert.areEqual(2, afterData.size());
    }
}
