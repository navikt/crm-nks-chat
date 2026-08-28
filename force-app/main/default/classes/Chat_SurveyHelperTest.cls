@isTest
private class Chat_SurveyHelperTest {
    private static void resetTestState() {
        Chat_SurveyHelper.testForceException = false;
        Chat_SurveyHelper.testHasInvitation = false;
        Chat_SurveyHelper.testInvitationLinkValue = null;
    }

    @TestSetup
    static void makeData() {
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        System.runAs(thisUser) {
            MessagingChannel channel = (MessagingChannel) UTIL_TestDataFactory.createRecord(new MessagingChannel());
            MessagingEndUser endUser = (MessagingEndUser) UTIL_TestDataFactory.createRecord(
                new MessagingEndUser(MessagingChannelId = channel.Id)
            );
            UTIL_TestDataFactory.createRecord(
                new MessagingSession(
                    MessagingChannelId = channel.Id,
                    MessagingEndUserId = endUser.Id,
                    SessionKey = 'testKey'
                )
            );
        }
    }

    @isTest
    static void testGetSurveyInvitationLinkReturnsEmptyWhenNoSurveyInvitationFound() {
        resetTestState();

        Test.startTest();
        String surveyInvitationLink = Chat_SurveyHelper.getSurveyInvitationLink('testKey');
        Test.stopTest();

        Assert.areEqual('', surveyInvitationLink);
    }

    @isTest
    static void testGetSurveyInvitationLinkReturnsInvitationLinkWhenFound() {
        resetTestState();
        Chat_SurveyHelper.testHasInvitation = true;
        Chat_SurveyHelper.testInvitationLinkValue = 'https://example.test/survey';

        Test.startTest();
        String surveyInvitationLink = Chat_SurveyHelper.getSurveyInvitationLink('testKey');
        Test.stopTest();

        Assert.areEqual('https://example.test/survey', surveyInvitationLink);
    }

    @isTest
    static void testGetSurveyInvitationLinkThrowsWhenSessionKeyIsBlank() {
        resetTestState();

        Test.startTest();
        try {
            Chat_SurveyHelper.getSurveyInvitationLink('');
            Assert.fail('Expected exception was not thrown');
        } catch (Exception e) {
            Assert.areEqual('sessionKey is required.', e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testGetSurveyInvitationLinkThrowsWrappedExceptionWhenUnexpectedErrorOccurs() {
        resetTestState();
        Chat_SurveyHelper.testForceException = true;

        Test.startTest();
        try {
            Chat_SurveyHelper.getSurveyInvitationLink('testKey');
            Assert.fail('Expected exception was not thrown');
        } catch (Exception e) {
            Assert.areEqual('Chat_SurveyHelper.ChatSurveyException', e.getTypeName());
            Assert.isTrue(e.getMessage().contains('An error has occurred while getting SurveyInvitation link.'));
            Assert.isTrue(e.getMessage().contains('sessionKey=testKey'));
            Assert.isTrue(e.getMessage().contains('forced test exception'));
        }
        Test.stopTest();
    }
}
