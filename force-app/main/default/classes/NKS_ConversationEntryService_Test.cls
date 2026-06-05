@isTest
private class NKS_ConversationEntryService_Test {
    @isTest
    static void testGetConversationEntryMessages_allNullOptionalParams() {
        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', '{}', null));

        Test.startTest();
        HttpResponse response = NKS_ConversationEntryService.getConversationEntryMessages(
            'test-conversation-id',
            null,
            null,
            null,
            null
        );
        Test.stopTest();

        Assert.areEqual(200, response.getStatusCode(), 'Expected 200 status code');
    }

    @isTest
    static void testGetConversationEntryMessages_withFromEndDirection() {
        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', '{}', null));

        Test.startTest();
        HttpResponse response = NKS_ConversationEntryService.getConversationEntryMessages(
            'test-conversation-id',
            1000000L,
            2000000L,
            'FROMEND',
            100
        );
        Test.stopTest();

        Assert.areEqual(200, response.getStatusCode(), 'Expected 200 status code');
    }

    @isTest
    static void testGetConversationEntryMessages_withFromStartDirection() {
        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', '{}', null));

        Test.startTest();
        HttpResponse response = NKS_ConversationEntryService.getConversationEntryMessages(
            'test-conversation-id',
            null,
            null,
            'FROMSTART',
            1000
        );
        Test.stopTest();

        Assert.areEqual(200, response.getStatusCode(), 'Expected 200 status code');
    }

    @isTest
    static void testGetConversationEntryMessages_withInvalidDirection() {
        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(400, 'Bad Request', '{}', null));

        Test.startTest();
        HttpResponse response = NKS_ConversationEntryService.getConversationEntryMessages(
            'test-conversation-id',
            1000000L,
            null,
            'INVALID_DIRECTION',
            50
        );
        Test.stopTest();

        Assert.areEqual(400, response.getStatusCode(), 'Expected 400 status code');
    }

    @isTest
    static void testGetConversationEntryMessages_withExcessiveRecordLimit() {
        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', '{}', null));

        Test.startTest();
        HttpResponse response = NKS_ConversationEntryService.getConversationEntryMessages(
            'test-conversation-id',
            null,
            null,
            'FROMEND',
            1001
        );
        Test.stopTest();

        Assert.areEqual(200, response.getStatusCode(), 'Expected 200 status code');
    }

    @isTest
    static void testGetConversationEntryMessages_withZeroRecordLimit() {
        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', '{}', null));

        Test.startTest();
        HttpResponse response = NKS_ConversationEntryService.getConversationEntryMessages(
            'test-conversation-id',
            null,
            null,
            null,
            0
        );
        Test.stopTest();

        Assert.areEqual(200, response.getStatusCode(), 'Expected 200 status code');
    }

    @isTest
    static void testDeleteConversationParticipantData() {
        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', '{}', null));

        Test.startTest();
        HttpResponse response = NKS_ConversationEntryService.deleteConversationParticipantData(
            new List<String>{ 'participantId1', 'participantId2' }
        );
        Test.stopTest();

        Assert.areEqual(200, response.getStatusCode(), 'Expected 200 status code');
    }
}
