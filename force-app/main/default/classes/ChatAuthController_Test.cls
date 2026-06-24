@isTest
public class ChatAuthController_Test {
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
    static void testSetStatusRequested() {
        Test.startTest();
        MessagingSession messagingSession = [SELECT Id FROM MessagingSession LIMIT 1];
        MessagingEndUser endUser = [SELECT Id FROM MessagingEndUser LIMIT 1];
        ChatAuthController.setStatusRequested(messagingSession.Id);

        //Testing exception
        try {
            ChatAuthController.setStatusRequested(endUser.Id);
        } catch (Exception ex) {
            System.assertEquals(new AuraHandledException('Test').getTypeName(), ex.getTypeName());
        }
        Test.stopTest();

        MessagingSession updatedSession = [
            SELECT Id, CRM_Authentication_Status__c
            FROM MessagingSession
            WHERE Id = :messagingSession.Id
        ];

        System.assertEquals('Authentication Requested', updatedSession.CRM_Authentication_Status__c);
    }

    @isTest
    static void testGetChatStatus() {
        Map<String, String> messagingStatus;

        Test.startTest();
        MessagingSession messSess = [SELECT Id FROM MessagingSession LIMIT 1];
        messagingStatus = ChatAuthController.getMessagingInfo(messSess.Id);

        //Testing exception
        try {
            ChatAuthController.getMessagingInfo('FAKEID');
        } catch (Exception ex) {
            System.assertEquals(new AuraHandledException('Test').getTypeName(), ex.getTypeName());
        }
        Test.stopTest();

        System.assertEquals('Not Started', messagingStatus.get('AUTH_STATUS'));
    }

    @isTest
    static void testGetCounselorName() {
        String fullname;
        MessagingSession messagingSession = [SELECT Id FROM MessagingSession LIMIT 1];

        Test.startTest();
        fullname = ChatAuthController.getCounselorName(messagingSession.Id);
        Test.stopTest();

        System.assert(String.isNotBlank(fullname));
    }
}
