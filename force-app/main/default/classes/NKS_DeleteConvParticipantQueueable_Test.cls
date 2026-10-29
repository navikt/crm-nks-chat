@IsTest
private class NKS_DeleteConvParticipantQueueable_Test {
    private static void runJob(Integer statusCode, Boolean throwsException) {
        NKS_RequestMock mock = new NKS_RequestMock(
            'callout:Conversation_Data_API/conversation-participants?participantEntityId=first,second&cascadeLevel=FULL_CASCADE',
            'DELETE',
            statusCode,
            'delete response'
        );
        if (throwsException) {
            mock.throwing();
        }
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        Id jobId = System.enqueueJob(new NKS_DeleteConvParticipantDataQueueable(new List<String>{ 'first', 'second' }));
        Test.stopTest();
        AsyncApexJob job = [SELECT Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId];
        Assert.areEqual('Completed', job.Status);
        Assert.areEqual(0, job.NumberOfErrors);
        if (throwsException) {
            NKS_MessagingTestFixture.assertLogged('Simulated participant callout failure');
        } else if (statusCode != 200) {
            NKS_MessagingTestFixture.assertLogged(
                'statusCode=503 | body=delete response | participantEntityIds=first,second'
            );
        } else {
            Test.getEventBus().deliver();
            Assert.areEqual(0, [SELECT COUNT() FROM Application_Log__c]);
        }
    }

    @IsTest
    static void successfulDelete() {
        runJob(200, false);
    }
    @IsTest
    static void rejectedDeleteIsLogged() {
        runJob(503, false);
    }
    @IsTest
    static void thrownCalloutIsLogged() {
        runJob(200, true);
    }
}
