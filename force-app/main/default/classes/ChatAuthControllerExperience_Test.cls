@IsTest
public class ChatAuthControllerExperience_Test {
    @TestSetup
    static void makeData() {
        NKS_MessagingTestFixture.createSession('New', false);
    }

    @isTest
    static void testSetStatusCompleted() {
        MessagingSession messagingSession = [SELECT Id FROM MessagingSession LIMIT 1];

        Test.startTest();
        ChatAuthControllerExperience.setStatusCompleted(messagingSession.Id);
        Test.stopTest();

        MessagingSession updatedSession = [
            SELECT Id, CRM_Authentication_Status__c
            FROM MessagingSession
            WHERE Id = :messagingSession.Id
        ];
        System.assertEquals('Completed', updatedSession.CRM_Authentication_Status__c);
    }

    @isTest
    static void testSetStatus_noEndUserAccount_triggersHandleChatAuthentication() {
        MessagingSession session = NKS_MessagingTestFixture.createSession('Active', false);

        Test.startTest();
        ChatAuthControllerExperience.setStatusCompleted(session.Id);
        Test.stopTest();

        MessagingSession result = [
            SELECT CRM_Authentication_Status__c
            FROM MessagingSession
            WHERE Id = :session.Id
        ];
        Assert.areEqual('Completed', result.CRM_Authentication_Status__c, 'Status should be Completed');
    }

    @isTest
    static void testSetStatus_nonExistentId_throwsAuraHandledException() {
        Id nonExistentId = UserInfo.getUserId();
        Test.startTest();
        try {
            ChatAuthControllerExperience.setStatus(nonExistentId, 'Completed');
            Assert.fail('Expected AuraHandledException to be thrown');
        } catch (AuraHandledException e) {
            Assert.areEqual('System.AuraHandledException', e.getTypeName());
        }
        Test.stopTest();
    }

    @isTest
    static void testGetCommunityAuthUrl() {
        String communityUrl;

        Test.startTest();
        communityUrl = ChatAuthControllerExperience.getCommunityAuthUrl();
        Test.stopTest();

        System.assert(String.isNotBlank(communityUrl));
    }
}
