@isTest
private class nksFridaLog_Test {
    @isTest
    static void testGetChatbotMessage_isChatTranscript_caseNotFound_returnsError() {
        Id fakeChatId = UserInfo.getUserId();
        Id fakeAccountId = UserInfo.getUserId();

        Test.startTest();
        String result = nksFridaLog.getChatbotMessage(fakeChatId, fakeAccountId, true);
        Test.stopTest();

        Assert.areEqual('Det oppstod en feil', result, 'Should return error message when no matching case is found');
    }

    @isTest
    static void testGetChatbotMessage_notChatTranscript_threadNotFound_returnsError() {
        Id fakeChatId = UserInfo.getUserId();
        Id fakeAccountId = UserInfo.getUserId();

        Test.startTest();
        String result = nksFridaLog.getChatbotMessage(fakeChatId, fakeAccountId, false);
        Test.stopTest();

        Assert.areEqual('Det oppstod en feil', result, 'Should return error message when no matching thread is found');
    }
}
