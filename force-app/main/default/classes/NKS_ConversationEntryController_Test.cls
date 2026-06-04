@isTest
private class NKS_ConversationEntryController_Test {
    @TestSetup
    static void makeData() {
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
        }
    }

    @isTest
    static void testConvertConversationEntries_authenticatedChat_createsOnlyAgentChatMessages() {
        MessagingSession messagingSession = [
            SELECT Id, CRM_Authentication_Status__c, NKS_Authentication_Timestamp__c
            FROM MessagingSession
            LIMIT 1
        ];

        String messagingSessionId = messagingSession.Id;

        String jsonResponse =
            '{' +
            '"conversationEntries":[' +
            '{' +
            '"clientDuration":0,' +
            '"clientTimestamp":1732111810339,' +
            '"identifier":"entry1",' +
            '"messageText":"Frida: Hei! Jeg heter Frida og er NAVs chatbot.\\nFrida: Hva lurer du på?\\nBruker: menneske\\nFrida: Det er mange som trenger hjelp fra oss nå.",' +
            '"relatedRecords":["' +
            messagingSessionId +
            '"],' +
            '"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},' +
            '"serverReceivedTimestamp":1732111810339' +
            '},' +
            '{' +
            '"clientDuration":0,' +
            '"clientTimestamp":1732111810707,' +
            '"identifier":"entry2",' +
            '"messageText":"Frida: Jeg setter deg over, et øyeblikk.\\nFrida: Det er mange som vil snakke med oss nå. Hold chatten åpen og følg med, så svarer vi deg så snart vi kan.",' +
            '"relatedRecords":["' +
            messagingSessionId +
            '"],' +
            '"sender":{"appType":"iamessage","role":"System","subject":"system-user"},' +
            '"serverReceivedTimestamp":1732111810707' +
            '},' +
            '{' +
            '"clientDuration":0,' +
            '"clientTimestamp":1732111834844,' +
            '"identifier":"entry3",' +
            '"messageText":"Melding fra veileder.",' +
            '"relatedRecords":["' +
            messagingSessionId +
            '"],' +
            '"sender":{"appType":"agent","role":"Agent","subject":"0052o000009d7J9"},' +
            '"serverReceivedTimestamp":1732111834844' +
            '},' +
            '{' +
            '"clientDuration":0,' +
            '"clientTimestamp":1732111856855,' +
            '"identifier":"entry4",' +
            '"messageText":"Melding fra bruker.",' +
            '"relatedRecords":["' +
            messagingSessionId +
            '"],' +
            '"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},' +
            '"serverReceivedTimestamp":1732111856855' +
            '}' +
            ']}';

        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', jsonResponse, null));

        Test.startTest();
        messagingSession.CRM_Authentication_Status__c = 'Completed';
        messagingSession.NKS_Authentication_Timestamp__c = Datetime.now();
        update messagingSession;
        Test.stopTest();

        Thread__c thread = [
            SELECT Id, CRM_Additional_Information__c, CRM_isActive__c, CRM_Closed_Date__c
            FROM Thread__c
            WHERE CRM_Related_Object__c = :messagingSessionId
            LIMIT 1
        ];

        List<Message__c> messages = [
            SELECT Id, CRM_Message_Text__c, CRM_Type__c, CRM_From_Contact__c, CRM_From_User__c
            FROM Message__c
            WHERE CRM_Thread__c = :thread.Id
            ORDER BY CreatedDate ASC
        ];

        Assert.areEqual(3, messages.size(), 'Expected 3 messages: 1 auth event + 2 real chat messages.');

        Assert.areEqual('Event', messages[0].CRM_Type__c, 'First message should be auth event.');
        Assert.areEqual('Startet innlogget chat', messages[0].CRM_Message_Text__c, 'Expected Norwegian auth text.');

        Assert.areEqual('Message', messages[1].CRM_Type__c, 'Second record should be a chat message.');
        Assert.areEqual('Melding fra veileder.', messages[1].CRM_Message_Text__c, 'Agent message should be created.');

        Assert.areEqual('Message', messages[2].CRM_Type__c, 'Third record should be a chat message.');
        Assert.areEqual('Melding fra bruker.', messages[2].CRM_Message_Text__c, 'User message should be created.');

        Assert.isTrue(
            thread.CRM_Additional_Information__c.contains('Frida: Hei! Jeg heter Frida og er NAVs chatbot.'),
            'Frida history should be stored in additional information.'
        );
        Assert.isTrue(
            thread.CRM_Additional_Information__c.contains('Bruker: menneske'),
            'Pre-chat user lines should remain in additional information.'
        );
        Assert.isTrue(
            !thread.CRM_Additional_Information__c.contains('Melding fra veileder.'),
            'Actual agent chat should not be stored in additional information.'
        );
        Assert.isTrue(
            !thread.CRM_Additional_Information__c.contains('Melding fra bruker.'),
            'Actual user chat with agent should not be stored in additional information.'
        );
        Assert.areEqual(false, thread.CRM_isActive__c, 'Thread should be closed after processing.');
        Assert.areEqual(true, thread.CRM_Closed_Date__c != null, 'Thread closed date should be set.');
    }

    @isTest
    static void testConvertConversationEntries_skipsNonAuthenticatedSession() {
        MessagingSession messagingSession = [
            SELECT Id, CRM_Authentication_Status__c
            FROM MessagingSession
            LIMIT 1
        ];

        messagingSession.CRM_Authentication_Status__c = 'Not Started';
        update messagingSession;

        String messagingSessionId = messagingSession.Id;

        String jsonResponse =
            '{' +
            '"conversationEntries":[' +
            '{' +
            '"clientDuration":0,' +
            '"clientTimestamp":1732111810339,' +
            '"identifier":"entry1",' +
            '"messageText":"Frida: Hei",' +
            '"relatedRecords":["' +
            messagingSessionId +
            '"],' +
            '"sender":{"appType":"iamessage","role":"System","subject":"system-user"},' +
            '"serverReceivedTimestamp":1732111810339' +
            '}' +
            ']}';

        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', jsonResponse, null));

        Test.startTest();
        NKS_ConversationEntryController.convertConversationEntries(
            new List<MessagingSession>{ messagingSession },
            null,
            null,
            'FromStart',
            1000
        );
        Test.stopTest();

        Thread__c thread = [
            SELECT Id, CRM_Additional_Information__c
            FROM Thread__c
            WHERE CRM_Related_Object__c = :messagingSessionId
            LIMIT 1
        ];

        List<Message__c> messages = [
            SELECT Id
            FROM Message__c
            WHERE CRM_Thread__c = :thread.Id
        ];

        Assert.areEqual(0, messages.size(), 'No messages should be created for non-authenticated chats.');
        Assert.areEqual(null, thread.CRM_Additional_Information__c, 'Thread should not be processed.');
    }

    @isTest
    static void testGetConversationEntryMessages() {
        MessagingSession messagingSession = [
            SELECT Id, Conversation.ConversationIdentifier
            FROM MessagingSession
            LIMIT 1
        ];

        String messagingSessionId = messagingSession.Id;
        String conversationIdentifier = messagingSession.Conversation.ConversationIdentifier;
        Long startTimestamp = 1732111834877L;
        Long endTimestamp = 1732111856833L;
        String queryDirection = 'FromStart';
        Integer recordLimit = 10;

        String jsonResponse =
            '{' +
            '"conversationEntries":[' +
            '{' +
            '"clientDuration":0,' +
            '"clientTimestamp":1732111810339,' +
            '"identifier":"entry1",' +
            '"messageText":"Frida: Første chatbotmelding fra Frida.",' +
            '"relatedRecords":["' +
            messagingSessionId +
            '"],' +
            '"sender":{"appType":"iamessage","role":"System","subject":"system-user"},' +
            '"serverReceivedTimestamp":1732111810339' +
            '}' +
            ']}';

        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', jsonResponse, null));

        Test.startTest();
        HttpResponse response = NKS_ConversationEntryService.getConversationEntryMessages(
            conversationIdentifier,
            startTimestamp,
            endTimestamp,
            queryDirection,
            recordLimit
        );
        Test.stopTest();

        Assert.areEqual(200, response.getStatusCode(), 'Expected status code 200');
    }

    @isTest
    static void testConvertConversationEntries_nullInput_noError() {
        Test.startTest();
        NKS_ConversationEntryController.convertConversationEntries(null, null, null, 'FromStart', 1000);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle null session list without throwing an exception.');
    }

    @isTest
    static void testConvertConversationEntries_emptyList_noError() {
        Test.startTest();
        NKS_ConversationEntryController.convertConversationEntries(
            new List<MessagingSession>(),
            null,
            null,
            'FromStart',
            1000
        );
        Test.stopTest();

        Assert.isTrue(true, 'Should handle empty session list without throwing an exception.');
    }

    @isTest
    static void testConvertConversationEntries_httpError_noMessagesCreated() {
        MessagingSession messagingSession = [
            SELECT Id, CRM_Authentication_Status__c
            FROM MessagingSession
            LIMIT 1
        ];

        String messagingSessionId = messagingSession.Id;

        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(500, 'Internal Server Error', '{}', null));

        Test.startTest();
        messagingSession.CRM_Authentication_Status__c = 'Completed';
        update messagingSession;
        Test.stopTest();

        Thread__c thread = [
            SELECT Id
            FROM Thread__c
            WHERE CRM_Related_Object__c = :messagingSessionId
            LIMIT 1
        ];

        List<Message__c> messages = [SELECT Id FROM Message__c WHERE CRM_Thread__c = :thread.Id];

        Assert.areEqual(0, messages.size(), 'No messages should be created when the HTTP callout returns an error.');
    }

    @isTest
    static void testConvertConversationEntries_richLinkEntry_usesUrlAsMessageText() {
        MessagingSession messagingSession = [
            SELECT Id, CRM_Authentication_Status__c
            FROM MessagingSession
            LIMIT 1
        ];

        String messagingSessionId = messagingSession.Id;

        String jsonResponse =
            '{"conversationEntries":[' +
            '{' +
            '"clientDuration":0,"clientTimestamp":1732111810339,"identifier":"entry1",' +
            '"relatedRecords":["' +
            messagingSessionId +
            '"],' +
            '"sender":{"appType":"agent","role":"Agent","subject":"0052o000009d7J9"},' +
            '"serverReceivedTimestamp":1732111810339,' +
            '"entryPayload":{"abstractMessage":{"staticContent":{"formatType":"RichLink","linkItem":{"url":"https://www.nav.no/syk/sykefravaer"}}}}' +
            '}' +
            ']}';

        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', jsonResponse, null));

        Test.startTest();
        messagingSession.CRM_Authentication_Status__c = 'Completed';
        update messagingSession;
        Test.stopTest();

        Thread__c thread = [
            SELECT Id
            FROM Thread__c
            WHERE CRM_Related_Object__c = :messagingSessionId
            LIMIT 1
        ];

        List<Message__c> messages = [
            SELECT Id, CRM_Message_Text__c
            FROM Message__c
            WHERE CRM_Thread__c = :thread.Id
        ];

        Assert.areEqual(1, messages.size(), 'Expected 1 message created for the RichLink entry.');
        Assert.areEqual(
            'https://www.nav.no/syk/sykefravaer',
            messages[0].CRM_Message_Text__c,
            'Message text should be the URL from the RichLink static content.'
        );
    }

    @isTest
    static void testConvertConversationEntries_staticContentTextEntry_usesTextAsMessageText() {
        MessagingSession messagingSession = [
            SELECT Id, CRM_Authentication_Status__c
            FROM MessagingSession
            LIMIT 1
        ];

        String messagingSessionId = messagingSession.Id;

        String jsonResponse =
            '{"conversationEntries":[' +
            '{' +
            '"clientDuration":0,"clientTimestamp":1732111810339,"identifier":"entry1",' +
            '"relatedRecords":["' +
            messagingSessionId +
            '"],' +
            '"sender":{"appType":"agent","role":"Agent","subject":"0052o000009d7J9"},' +
            '"serverReceivedTimestamp":1732111810339,' +
            '"entryPayload":{"abstractMessage":{"staticContent":{"formatType":"Text","text":"Hei! Kan jeg hjelpe deg?"}}}' +
            '}' +
            ']}';

        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', jsonResponse, null));

        Test.startTest();
        messagingSession.CRM_Authentication_Status__c = 'Completed';
        update messagingSession;
        Test.stopTest();

        Thread__c thread = [
            SELECT Id
            FROM Thread__c
            WHERE CRM_Related_Object__c = :messagingSessionId
            LIMIT 1
        ];

        List<Message__c> messages = [
            SELECT Id, CRM_Message_Text__c
            FROM Message__c
            WHERE CRM_Thread__c = :thread.Id
        ];

        Assert.areEqual(1, messages.size(), 'Expected 1 message created for the Text static content entry.');
        Assert.areEqual(
            'Hei! Kan jeg hjelpe deg?',
            messages[0].CRM_Message_Text__c,
            'Message text should come from the staticContent text field for non-RichLink format.'
        );
    }

    @isTest
    static void testRetryDeleteParticipantData_executesWithoutError() {
        MessagingEndUser endUser = [SELECT Id FROM MessagingEndUser LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', '{}', null));

        Test.startTest();
        NKS_ConversationEntryController.retryDeleteParticipantData(new List<String>{ endUser.Id });
        Test.stopTest();

        Assert.isTrue(true, 'retryDeleteParticipantData should complete without throwing an exception.');
    }

    @isTest
    static void testDeleteSessionDataAndEnqueueCallout_executesWithoutError() {
        MessagingSession msgSession = [SELECT Id, MessagingEndUserId FROM MessagingSession LIMIT 1];
        Set<Id> sessionIds = new Set<Id>{ msgSession.Id };
        List<String> participantEntityIds = new List<String>{ String.valueOf(msgSession.MessagingEndUserId) };

        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', '{}', null));

        Test.startTest();
        NKS_ConversationEntryController.deleteSessionDataAndEnqueueCallout(sessionIds, participantEntityIds);
        Test.stopTest();

        Assert.isTrue(true, 'deleteSessionDataAndEnqueueCallout should complete without throwing an exception.');
    }
}
