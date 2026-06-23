@isTest
private class NKS_MessagingSessionHandler_Test {
    @TestSetup
    static void makeData() {
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(thisUser) {
            MessagingChannel msgChannel = new MessagingChannel();
            msgChannel.MasterLabel = 'TestHandlerChannel';
            msgChannel.DeveloperName = 'TestHandlerChannel';
            msgChannel.IsActive = true;
            msgChannel.MessageType = 'Text';
            msgChannel.MessagingPlatformKey = 'TestHandlerChannel';
            insert msgChannel;

            MessagingEndUser msgEndUser = new MessagingEndUser();
            msgEndUser.Name = 'Handler Test User';
            msgEndUser.MessagingChannelId = msgChannel.Id;
            msgEndUser.MessageType = 'EmbeddedMessaging';
            msgEndUser.MessagingPlatformKey = 'TestHandlerChannel';
            insert msgEndUser;

            // Status and EndTime are set on insert — Status is not writable via update
            MessagingSession msgSession = new MessagingSession();
            msgSession.MessagingEndUserId = msgEndUser.Id;
            msgSession.MessagingChannelId = msgChannel.Id;
            msgSession.Status = 'Ended';
            msgSession.EndTime = Datetime.now().addMinutes(-5);
            insert msgSession;
        }
    }

    @isTest
    static void testOnAfterUpdate_MessagingSessionStartsQueueable() {
        MessagingSession msgSession = [SELECT Id FROM MessagingSession LIMIT 1];

        String jsonResponse =
            '{"conversationEntries":[' +
            '{"clientDuration":0,"clientTimestamp":1732111834844,"identifier":"entry1",' +
            '"messageText":"Melding fra veileder.",' +
            '"relatedRecords":["' +
            msgSession.Id +
            '"],' +
            '"sender":{"appType":"agent","role":"Agent","subject":"0052o000009d7J9"},' +
            '"transcriptedTimestamp":1732111834844}' +
            ']}';

        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', jsonResponse, null));

        Integer jobsBefore = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE JobType = 'Queueable' AND ApexClass.Name = 'NKS_ConversationEntryQueueable'
        ];

        Test.startTest();
        msgSession.CRM_Authentication_Status__c = 'Completed';
        update msgSession;
        Test.stopTest();

        Integer jobsAfter = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE JobType = 'Queueable' AND ApexClass.Name = 'NKS_ConversationEntryQueueable'
        ];
        Assert.areNotEqual(
            jobsBefore,
            jobsAfter,
            'Handler should enqueue 1 conversion job when session auth is completed.'
        );
    }

    @isTest
    static void testOnAfterUpdate_MessagingSessionNotAuthenticated() {
        MessagingSession msgSession = [SELECT Id FROM MessagingSession LIMIT 1];

        Integer jobsBefore = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE JobType = 'Queueable' AND ApexClass.Name = 'NKS_ConversationEntryQueueable'
        ];

        Test.startTest();
        msgSession.CRM_Authentication_Status__c = 'Not Started';
        update msgSession;
        Test.stopTest();

        Integer jobsAfter = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE JobType = 'Queueable' AND ApexClass.Name = 'NKS_ConversationEntryQueueable'
        ];
        Assert.areEqual(
            jobsBefore,
            jobsAfter,
            'No conversion job should be enqueued when authentication is not completed.'
        );
    }
}
