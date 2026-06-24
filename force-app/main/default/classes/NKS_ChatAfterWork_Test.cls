@IsTest
public with sharing class NKS_ChatAfterWork_Test {
    @IsTest
    static void ThreatReportTest() {
        Test.startTest();
        NKS_ChatAfterWork.reportThreatClick();
        Test.stopTest();
        Assert.areEqual(1, [SELECT Id FROM ReportingData__c WHERE CRM_Category__c = 'Chat Threat'].size());
    }

    @IsTest
    static void ThreatValueTest() {
        Test.startTest();
        Id reportId = NKS_ChatAfterWork.reportThreatClick();
        NKS_ChatAfterWork.updateThreatClickValue(reportId, 15000);
        Test.stopTest();
        ReportingData__c report = [
            SELECT Id, CRM_Value__c
            FROM ReportingData__c
            WHERE CRM_Category__c = 'Chat Threat'
            LIMIT 1
        ];
        Assert.areEqual(15000, report.CRM_Value__c);
    }

    @IsTest
    static void testUpdateThreatClickValue_invalidId_throwsAuraHandledException() {
        Id invalidId = UserInfo.getUserId();
        Test.startTest();
        try {
            NKS_ChatAfterWork.updateThreatClickValue(invalidId, 1);
            Assert.fail('Expected AuraHandledException to be thrown');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException should be thrown for an invalid record Id');
        }
        Test.stopTest();
    }
}
