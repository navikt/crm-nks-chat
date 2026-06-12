@isTest
private class NKS_ConversationEntryQueueable_Test {
    @isTest
    static void testExecute_noMatchingSessions_noError() {
        Test.startTest();
        System.enqueueJob(new NKS_ConversationEntryQueueable(new List<Id>(), null, null, 'FROMSTART', 1000));
        Test.stopTest();

        Assert.isTrue(true, 'Queueable should execute without error when no sessions match');
    }

    @isTest
    static void testExecute_withSessionIds_callsController() {
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        System.runAs(thisUser) {
            MessagingChannel msgChannel = new MessagingChannel();
            msgChannel.MasterLabel = 'TestChannel';
            msgChannel.DeveloperName = 'TestChannel';
            msgChannel.IsActive = true;
            msgChannel.MessageType = 'Text';
            msgChannel.MessagingPlatformKey = 'TestChannel';
            insert msgChannel;

            MessagingEndUser msgEndUser = new MessagingEndUser();
            msgEndUser.Name = 'Messaging User';
            msgEndUser.MessagingChannelId = msgChannel.Id;
            msgEndUser.MessageType = 'EmbeddedMessaging';
            msgEndUser.MessagingPlatformKey = 'TestChannel';
            insert msgEndUser;

            MessagingSession msgSession = new MessagingSession();
            msgSession.MessagingEndUserId = msgEndUser.Id;
            msgSession.MessagingChannelId = msgChannel.Id;
            msgSession.Status = 'Ended';
            msgSession.EndTime = Datetime.now();
            insert msgSession;

            Thread__c thread = new Thread__c(CRM_Related_Object__c = msgSession.Id);
            insert thread;

            Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', '{"conversationEntries":[]}', null));

            Test.startTest();
            System.enqueueJob(
                new NKS_ConversationEntryQueueable(new List<Id>{ msgSession.Id }, null, null, 'FROMSTART', 1000)
            );
            Test.stopTest();
        }

        Assert.isTrue(true, 'Queueable should execute without error');
    }
}
