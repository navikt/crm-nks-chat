@IsTest
private class NKS_ConversationEntryQueueable_Test {
    @IsTest
    static void emptyJobCompletesWithoutSideEffects() {
        Test.startTest();
        Id jobId = System.enqueueJob(new NKS_ConversationEntryQueueable(new List<Id>(), null, null, 'FROMSTART', 1000));
        Test.stopTest();
        assertCompleted(jobId);
        Assert.areEqual(0, [SELECT COUNT() FROM Message__c]);
        Assert.areEqual(0, [SELECT COUNT() FROM Application_Log__c]);
    }

    @IsTest
    static void jobPassesSessionToControllerAndLogsMissingConversation() {
        MessagingSession session = NKS_MessagingTestFixture.createSession('Ended', true);
        MyTriggers.disable(NKS_MessagingSessionHandler.class);
        session.CRM_Authentication_Status__c = 'Completed';
        update session;
        Test.startTest();
        Id jobId = System.enqueueJob(
            new NKS_ConversationEntryQueueable(new List<Id>{ session.Id }, null, null, 'FROMSTART', 1000)
        );
        Test.stopTest();
        assertCompleted(jobId);
        Assert.areEqual(0, [SELECT COUNT() FROM Message__c]);
        NKS_MessagingTestFixture.assertLogged('conversationIdentifier is null | sessionId=' + session.Id);
    }

    private static void assertCompleted(Id jobId) {
        AsyncApexJob job = [SELECT Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId];
        Assert.areEqual('Completed', job.Status);
        Assert.areEqual(0, job.NumberOfErrors);
    }
}
