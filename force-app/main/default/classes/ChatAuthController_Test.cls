@IsTest
public class ChatAuthController_Test {
    @TestSetup
    static void setup() {
        NKS_MessagingTestFixture.createSession('New', false);
    }

    @IsTest
    static void statusRequestPersists() {
        MessagingSession session = [SELECT Id FROM MessagingSession LIMIT 1];
        Test.startTest();
        ChatAuthController.setStatusRequested(session.Id);
        Test.stopTest();
        Assert.areEqual(
            'Authentication Requested',
            [SELECT CRM_Authentication_Status__c FROM MessagingSession WHERE Id = :session.Id]
            .CRM_Authentication_Status__c
        );
    }

    @IsTest
    static void statusRequestRejectsWrongObjectAndPreservesSession() {
        MessagingEndUser endUser = [SELECT Id FROM MessagingEndUser LIMIT 1];
        Test.startTest();
        try {
            ChatAuthController.setStatusRequested(endUser.Id);
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            Assert.areEqual('System.AuraHandledException', ex.getTypeName());
        }
        Test.stopTest();
        Assert.areEqual(
            'Not Started',
            [SELECT CRM_Authentication_Status__c FROM MessagingSession LIMIT 1].CRM_Authentication_Status__c
        );
    }

    @IsTest
    static void messagingInfoReturnsCompleteContract() {
        MessagingSession session = [
            SELECT Id, CRM_Authentication_Status__c, EndTime, Status, CRM_Language__c
            FROM MessagingSession
            LIMIT 1
        ];
        Test.startTest();
        Map<String, String> actual = ChatAuthController.getMessagingInfo(session.Id);
        Test.stopTest();
        Assert.areEqual(
            new Map<String, String>{
                'AUTH_STATUS' => session.CRM_Authentication_Status__c,
                'END_TIME' => String.valueOf(session.EndTime),
                'CONVERSATION_STATUS' => session.Status,
                'CHAT_LANGUAGE' => session.CRM_Language__c
            },
            actual
        );
    }

    @IsTest
    static void messagingInfoRejectsInvalidId() {
        Test.startTest();
        try {
            ChatAuthController.getMessagingInfo('FAKEID');
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            Assert.areEqual('System.AuraHandledException', ex.getTypeName());
        }
        Test.stopTest();
        Assert.areEqual(1, [SELECT COUNT() FROM MessagingSession]);
    }

    @IsTest
    static void counselorNameMatchesOwner() {
        MessagingSession session = [SELECT Id, OwnerId FROM MessagingSession LIMIT 1];
        String expected = [SELECT NKS_FullName__c FROM User WHERE Id = :session.OwnerId].NKS_FullName__c;
        Test.startTest();
        String actual = ChatAuthController.getCounselorName(session.Id);
        Test.stopTest();
        Assert.areEqual(expected, actual);
    }
}
