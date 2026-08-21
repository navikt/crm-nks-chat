@IsTest
public with sharing class NKS_MessagingSessionReportData_Test {
    @TestSetup
    static void makeData() {
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(thisUser) {
            MessagingChannel msgChannel = new MessagingChannel();
            msgChannel.MasterLabel = 'TestChannel';
            msgChannel.DeveloperName = 'TestChannel';
            msgChannel.IsActive = true;
            msgChannel.MessageType = 'Text';
            msgChannel.MessagingPlatformKey = 'TestChannel';
            insert msgChannel;

            MessagingEndUser msgEndUser = new MessagingEndUser();
            msgEndUser.Name = 'Messaging User';
            msgEndUser.MessagingChannelId = msgChannel.Id;
            msgEndUser.MessageType = 'EmbeddedMessaging';
            msgEndUser.MessagingPlatformKey = 'TestChannel';
            insert msgEndUser;

            MessagingSession msgSession = new MessagingSession();
            msgSession.MessagingEndUserId = msgEndUser.Id;
            msgSession.MessagingChannelId = msgChannel.Id;
            msgSession.Status = 'Ended';
            msgSession.EndTime = Datetime.now();
            insert msgSession;
        }
    }

    @IsTest
    static void copyToReportingData_createsReportingDataWithJson() {
        MessagingSession session = [SELECT Id FROM MessagingSession LIMIT 1];

        Test.startTest();
        NKS_MessagingSessionReportData.copyToReportingData(new Set<Id>{ session.Id });
        Test.stopTest();

        ReportingData__c report = [
            SELECT Id, NKS_Has_Messaging_Session__c, NKS_Messaging_Session__c
            FROM ReportingData__c
            WHERE CRM_Category__c = 'Chat'
            LIMIT 1
        ];
        Assert.isTrue(report.NKS_Has_Messaging_Session__c);
        Assert.isTrue(report.NKS_Messaging_Session__c.contains('"Status":"Ended"'));
    }

    @IsTest
    static void copyToReportingData_emptySet_doesNothing() {
        Test.startTest();
        NKS_MessagingSessionReportData.copyToReportingData(new Set<Id>());
        NKS_MessagingSessionReportData.copyToReportingData(null);
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM ReportingData__c WHERE CRM_Category__c = 'Chat']);
    }
}
