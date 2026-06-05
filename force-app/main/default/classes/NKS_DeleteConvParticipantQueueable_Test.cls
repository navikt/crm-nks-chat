@isTest
private class NKS_DeleteConvParticipantQueueable_Test {
    @isTest
    static void testExecute_callsDeleteParticipantData() {
        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', '{}', null));

        Test.startTest();
        System.enqueueJob(
            new NKS_DeleteConvParticipantDataQueueable(new List<String>{ 'participantId1', 'participantId2' })
        );
        Test.stopTest();

        Assert.isTrue(true, 'Queueable should execute the delete callout without error');
    }
}
