@IsTest
private class NKS_ConversationEntryService_Test {
    private static void assertGet(Long startTime, Long endTime, String direction, Integer recordLimit, String query) {
        NKS_RequestMock mock = new NKS_RequestMock(
            'callout:Conversation_Data_API/conversation-entries?conversationIdentifier=test-conversation-id' + query,
            'GET',
            200,
            '{"conversationEntries":[]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);
        HttpResponse response = NKS_ConversationEntryService.getConversationEntryMessages(
            'test-conversation-id',
            startTime,
            endTime,
            direction,
            recordLimit
        );
        Assert.areEqual(1, mock.calls);
        Assert.areEqual(200, response.getStatusCode());
        Assert.areEqual('{"conversationEntries":[]}', response.getBody());
    }

    @IsTest
    static void optionalParametersAndBoundaries() {
        assertGet(null, null, null, null, '');
        assertGet(1000L, null, null, null, '&startTimestamp=1000');
        assertGet(null, 2000L, null, null, '&endTimestamp=2000');
        assertGet(1000L, 2000L, 'FROMEND', 1, '&startTimestamp=1000&endTimestamp=2000&direction=FROMEND&limit=1');
        assertGet(null, null, 'FROMSTART', 1000, '&direction=FROMSTART&limit=1000');
    }

    @IsTest
    static void invalidOptionsAreOmitted() {
        assertGet(null, null, 'INVALID_DIRECTION', 50, '&limit=50');
        assertGet(null, null, null, -1, '');
        assertGet(null, null, null, 0, '');
        assertGet(null, null, 'FROMEND', 1001, '&direction=FROMEND');
    }

    @IsTest
    static void deleteRequestAndErrorResponse() {
        NKS_RequestMock mock = new NKS_RequestMock(
            'callout:Conversation_Data_API/conversation-participants?participantEntityId=first,second&cascadeLevel=FULL_CASCADE',
            'DELETE',
            503,
            'Unavailable'
        );
        Test.setMock(HttpCalloutMock.class, mock);
        HttpResponse response = NKS_ConversationEntryService.deleteConversationParticipantData(
            new List<String>{ 'first', 'second' }
        );
        Assert.areEqual(1, mock.calls);
        Assert.areEqual(503, response.getStatusCode());
        Assert.areEqual('Unavailable', response.getBody());
    }

    @IsTest
    static void calloutExceptionPropagates() {
        Test.setMock(
            HttpCalloutMock.class,
            new NKS_RequestMock(
                    'callout:Conversation_Data_API/conversation-participants?participantEntityId=first&cascadeLevel=FULL_CASCADE',
                    'DELETE',
                    200,
                    '{}'
                )
                .throwing()
        );
        try {
            NKS_ConversationEntryService.deleteConversationParticipantData(new List<String>{ 'first' });
            Assert.fail('Expected callout exception');
        } catch (CalloutException ex) {
            Assert.areEqual('Simulated participant callout failure', ex.getMessage());
        }
    }
}
