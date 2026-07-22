@isTest
private class Chat_SurveyHelperTest {
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
    static void testGetSurveyInvitationLinkReturnsNullWhenNoSurveyInvitationFound() {
        Test.startTest();
        String surveyInvitationLink = Chat_SurveyHelper.getSurveyInvitationLink('testKey');
        Test.stopTest();

        Assert.isNull(surveyInvitationLink, 'Expected surveyInvitationLink to be null');
    }

    @isTest
    static void testGetSurveyInvitationLinkThrowsWhenSessionKeyIsBlank() {
        Test.startTest();
        try {
            Chat_SurveyHelper.getSurveyInvitationLink('');
            Assert.fail('Expected exception was not thrown');
        } catch (Exception e) {
            Assert.areEqual('sessionKey is required.', e.getMessage());
        }
        Test.stopTest();
    }
}
