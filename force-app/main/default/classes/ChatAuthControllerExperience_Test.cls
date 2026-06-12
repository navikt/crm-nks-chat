@IsTest
public class ChatAuthControllerExperience_Test {
    @TestSetup
    static void makeData() {
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        System.runAs(thisUser) {
            MessagingChannel channel = (MessagingChannel) UTIL_TestDataFactory.createRecord(new MessagingChannel());
            UTIL_TestDataFactory.createRecord(
                new MessagingSession(
                    MessagingChannelId = channel.Id,
                    MessagingEndUserId = UTIL_TestDataFactory.createRecord(
                            new MessagingEndUser(MessagingChannelId = channel.Id)
                        )
                        .Id
                )
            );
        }
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
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        MessagingSession session;
        System.runAs(thisUser) {
            MessagingChannel channel = new MessagingChannel();
            channel.MasterLabel = 'NoAccountChannel';
            channel.DeveloperName = 'NoAccountChannel';
            channel.IsActive = true;
            channel.MessageType = 'Text';
            channel.MessagingPlatformKey = 'NoAccountChannel';
            insert channel;

            MessagingEndUser endUser = new MessagingEndUser();
            endUser.Name = 'No Account User';
            endUser.MessagingChannelId = channel.Id;
            endUser.MessageType = 'EmbeddedMessaging';
            endUser.MessagingPlatformKey = 'NoAccountChannel';
            insert endUser;

            session = new MessagingSession();
            session.MessagingEndUserId = endUser.Id;
            session.MessagingChannelId = channel.Id;
            session.Status = 'Active';
            insert session;
        }

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
            Assert.isTrue(true, 'AuraHandledException should be thrown for non-existent session Id');
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
