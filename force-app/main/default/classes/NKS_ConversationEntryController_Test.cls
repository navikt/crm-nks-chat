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
            '"transcriptedTimestamp":1732111810339' +
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
            '"transcriptedTimestamp":1732111810707' +
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
            '"transcriptedTimestamp":1732111834844' +
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
            '"transcriptedTimestamp":1732111856855' +
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
            '"transcriptedTimestamp":1732111810339' +
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
            '"transcriptedTimestamp":1732111810339' +
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
    static void testConvertConversationEntries_sessionWithNullId_noError() {
        MessagingSession sessionWithNullId = new MessagingSession();

        Test.startTest();
        NKS_ConversationEntryController.convertConversationEntries(
            new List<MessagingSession>{ sessionWithNullId },
            null,
            null,
            'FromStart',
            1000
        );
        Test.stopTest();

        Assert.isTrue(true, 'Should return early without error when all sessions have null Ids.');
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
            '"transcriptedTimestamp":1732111810339,' +
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
            '"transcriptedTimestamp":1732111810339,' +
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
    static void testConvertConversationEntries_messageDataTime() {
        MessagingSession messagingSession = [
            SELECT Id, CRM_Authentication_Status__c
            FROM MessagingSession
            LIMIT 1
        ];

        String messagingSessionId = messagingSession.Id;

        String jsonResponse2 = '{"conversationIdentifier":"57eedd4d-5eea-4e31-8f25-1e568bbf16cf","conversationEntries":[{"identifier":"a91c316f-24de-4369-a679-dce4ad95b6a2","entryType":"ConversationUpdated","entryPayload":{"entryType":"ConversationUpdated","id":"a91c316f-24de-4369-a679-dce4ad95b6a2","updates":[{"updateType":"ModalityUpdate","transitionType":"Standard","activeModalities":["Messaging"]}],"updatedBy":{"role":"System","appType":"conversation","subject":"0052o000009GmW3","clientIdentifier":""}},"sender":{"role":"System","appType":"conversation","subject":"0052o000009GmW3","clientIdentifier":null},"recipients":{"secondary":null,"hidden":null,"primary":null},"transcriptedTimestamp":1782113315402,"relatedRecords":[],"clientTimestamp":1782113315402,"clientDuration":0},{"identifier":"4d5f107b-47b5-46c0-863e-5770443c9177","entryType":"Message","entryPayload":{"entryType":"Message","id":"4d5f107b-47b5-46c0-863e-5770443c9177","abstractMessage":{"inReplyToMessageId":null,"customHandlingType":null,"id":"4d5f107b-47b5-46c0-863e-5770443c9177","messageType":"StaticContentMessage","references":null,"contentCategory":null,"staticContent":{"formatType":"Text","text":"Frida:   Jeg kan sette deg over til et menneske for mer hjelp. \nFrida:   Velg et alternativ sÃ¥ setter jeg deg over:\nFrida:   [Knapp: AAP, jobbsÃ¸ker, permittert]\nFrida:   [Knapp: Foreldre, barn og familie]\nFrida:   [Knapp: STENGT: GjeldsrÃ¥dgivning]\nFrida:   [Knapp: Hjelpemiddel]\nFrida:   [Knapp: Pensjon]\nFrida:   [Knapp: Sosiale tjenester]\nFrida:   [Knapp: Sykepenger, grunn- og hjelpestÃ¸nad, yrkesskade, hjelpemiddel]\nFrida:   [Knapp: UfÃ¸retrygd]\nFrida:   [Knapp: Lege/samarbeidspartner]\nFrida:   [Knapp: Internasjonalt]\nBruker: menneske\nBruker: Trykket pÃ¥ [Knapp: Chat med menneske]\nFrida:   Jeg kan sette deg over til et menneske for mer hjelp. \nFrida:   Velg et alternativ sÃ¥ setter jeg deg over:\nFrida:   [Knapp: AAP, jobbsÃ¸ker, permittert]\nFrida:   [Knapp: Foreldre, barn og familie]\nFrida:   [Knapp: STENGT: GjeldsrÃ¥dgivning]\nFrida:   [Knapp: Hjelpemiddel]\nFrida:   [Knapp: Pensjon]\nFrida:   [Knapp: Sosiale tjenester]\nFrida:   [Knapp: Sykepenger, grunn- og hjelpestÃ¸nad, yrkesskade, hjelpemiddel]\nFrida:   [Knapp: UfÃ¸retrygd]\nFrida:   [Knapp: Lege/samarbeidspartner]\nFrida:   [Knapp: Internasjonalt]\nBruker: arbeid\nBruker: Trykket pÃ¥ [Knapp: AAP, jobbsÃ¸ker, permittert]\nFrida:   Jeg setter deg over, et Ã¸yeblikk.\nFrida:   Det er mange som vil snakke med oss nÃ¥. Hold chatten Ã¥pen og fÃ¸lg med, sÃ¥ svarer vi deg  sÃ¥ snart vi kan.","citationContent":null}},"messageReason":null,"wasRevised":null},"sender":{"role":"EndUser","appType":"iamessage","subject":"v2/iamessage/UNAUTH/NA/uid:423b4911-f578-4762-8aba-1de448c5d8ab","clientIdentifier":null},"recipients":{"secondary":null,"hidden":null,"primary":null},"transcriptedTimestamp":1782113316725,"relatedRecords":["0Mwds000007kpwN"],"clientTimestamp":1782113316674,"clientDuration":0},{"identifier":"be1b9265-fc1d-451f-8f8d-aa3aedaaf833","entryType":"RoutingResult","entryPayload":{"entryType":"RoutingResult","id":"be1b9265-fc1d-451f-8f8d-aa3aedaaf833","workOwnerId":null,"estimatedWaitTime":{"estimatedWaitTimeInSeconds":null,"isEWTRequested":false},"initiator":null,"workId":null,"recordId":"0Mwds000007kpwN","errorMessages":[],"pendingServiceRoutingId":"0JRds000008nw7t","skipRouterCPRemovalIfNoRoutingFailures":true,"routingType":"Initial","failureReason":"","failureType":"None","isExternallyRouted":false,"cancelReason":null,"routingConfigurationDetails":{"routingConfigurationType":"QueueRoutingType","queueId":"00GKD000000hau0"}},"sender":{"role":"System","appType":"conversation","subject":"0052o000009GmW3","clientIdentifier":null},"recipients":{"secondary":null,"hidden":null,"primary":null},"transcriptedTimestamp":1782113319224,"relatedRecords":[],"clientTimestamp":1782113319187,"clientDuration":0},{"identifier":"cdef29c3-5ad6-4e26-8c0d-10b1d986dd24","entryType":"ParticipantChanged","entryPayload":{"entryType":"ParticipantChanged","id":"cdef29c3-5ad6-4e26-8c0d-10b1d986dd24","entries":[{"operation":"add","menuMetadata":null,"supportedModalities":null,"participant":{"role":"Agent","appType":"agent","subject":"0052o000009d7J9","clientIdentifier":""},"displayName":"Eirik F"}],"activeModalities":["Messaging"]},"sender":{"role":"System","appType":"conversation","subject":"0052o000009GmW3","clientIdentifier":null},"recipients":{"secondary":null,"hidden":null,"primary":null},"transcriptedTimestamp":1782113391643,"relatedRecords":[],"clientTimestamp":1782113391643,"clientDuration":0},{"identifier":"bd2065d3-d309-4f84-b211-f30f666e918f","entryType":"SessionStatusChanged","entryPayload":{"entryType":"SessionStatusChanged","id":"bd2065d3-d309-4f84-b211-f30f666e918f","conversationIdentifier":"57eedd4d-5eea-4e31-8f25-1e568bbf16cf","channelAddressIdentifier":"95997dc5-3041-4b64-9b2b-43e54d7312df","sessionStatusPrev":"Waiting","sessionEndedByRole":null,"sessionEndTime":null,"sessionStatus":"Active","sessionStartTime":1782113315000,"sessionId":"0Mwds000007kpwN"},"sender":{"role":"System","appType":"conversation","subject":"0052o000009GmW3","clientIdentifier":null},"recipients":{"secondary":null,"hidden":null,"primary":null},"transcriptedTimestamp":1782113392259,"relatedRecords":[],"clientTimestamp":1782113392000,"clientDuration":0},{"identifier":"8d41bc7a-f0f2-495b-8b2e-db9197213c63","entryType":"Message","entryPayload":{"entryType":"Message","id":"8d41bc7a-f0f2-495b-8b2e-db9197213c63","abstractMessage":{"inReplyToMessageId":null,"customHandlingType":null,"id":"8d41bc7a-f0f2-495b-8b2e-db9197213c63","messageType":"StaticContentMessage","references":null,"contentCategory":null,"staticContent":{"formatType":"Text","text":"Velkommen til chat med NAV. Dette er en uinnlogget chat og vi ber deg ikke oppgi person - eller saksopplysninger. Vi kan kun gi deg generell veiledning. Du snakker med Eirik. Gi meg et lite Ã¸yeblikk slik at jeg kan se over dialogen du har hatt sÃ¥ langt.","citationContent":null}},"messageReason":"AutomatedResponse","wasRevised":null},"sender":{"role":"System","appType":"conversation","subject":"0052o000009GmW3","clientIdentifier":null},"recipients":{"secondary":null,"hidden":null,"primary":[{"identifier":"43bc44cc-37ae-31b7-bd68-285386c3840b","displayName":"Eirik F","contact":"0052o000009d7J9"},{"identifier":"8ccef6f3-4e2a-3068-ae87-a68d623e335c","displayName":"Guest","contact":"v2/iamessage/UNAUTH/NA/uid:423b4911-f578-4762-8aba-1de448c5d8ab"}]},"transcriptedTimestamp":1782113392995,"relatedRecords":[],"clientTimestamp":1782113392000,"clientDuration":0},{"identifier":"5a957a97-4a8c-46c0-a4a8-105899e51603","entryType":"Message","entryPayload":{"entryType":"Message","id":"5a957a97-4a8c-46c0-a4a8-105899e51603","abstractMessage":{"inReplyToMessageId":null,"customHandlingType":null,"id":"5a957a97-4a8c-46c0-a4a8-105899e51603","messageType":"StaticContentMessage","references":null,"contentCategory":null,"staticContent":{"formatType":"Text","text":"Heisann","citationContent":null}},"messageReason":null,"wasRevised":null},"sender":{"role":"EndUser","appType":"iamessage","subject":"v2/iamessage/UNAUTH/NA/uid:423b4911-f578-4762-8aba-1de448c5d8ab","clientIdentifier":null},"recipients":{"secondary":null,"hidden":null,"primary":null},"transcriptedTimestamp":1782113402970,"relatedRecords":["0Mwds000007kpwN"],"clientTimestamp":1782113402869,"clientDuration":0},{"identifier":"fe605a81-dfba-45f5-8d5b-e1ee28fb6b07","entryType":"Message","entryPayload":{"entryType":"Message","id":"fe605a81-dfba-45f5-8d5b-e1ee28fb6b07","abstractMessage":{"inReplyToMessageId":null,"customHandlingType":null,"id":"fe605a81-dfba-45f5-8d5b-e1ee28fb6b07","messageType":"StaticContentMessage","references":[],"contentCategory":null,"staticContent":{"formatType":"Text","text":"yo","citationContent":null}},"messageReason":null,"wasRevised":null},"sender":{"role":"Agent","appType":"agent","subject":"0052o000009d7J9","clientIdentifier":null},"recipients":{"secondary":null,"hidden":null,"primary":null},"transcriptedTimestamp":1782113403953,"relatedRecords":["0Mwds000007kpwN"],"clientTimestamp":1782113403875,"clientDuration":0},{"identifier":"9997ca41-f5d7-4654-a632-9ae8a59dff88","entryType":"Message","entryPayload":{"entryType":"Message","id":"9997ca41-f5d7-4654-a632-9ae8a59dff88","abstractMessage":{"inReplyToMessageId":null,"customHandlingType":null,"id":"9997ca41-f5d7-4654-a632-9ae8a59dff88","messageType":"StaticContentMessage","references":null,"contentCategory":null,"staticContent":{"formatType":"Text","text":"Erru dum eller","citationContent":null}},"messageReason":null,"wasRevised":null},"sender":{"role":"EndUser","appType":"iamessage","subject":"v2/iamessage/UNAUTH/NA/uid:423b4911-f578-4762-8aba-1de448c5d8ab","clientIdentifier":null},"recipients":{"secondary":null,"hidden":null,"primary":null},"transcriptedTimestamp":1782113408088,"relatedRecords":["0Mwds000007kpwN"],"clientTimestamp":1782113408065,"clientDuration":0},{"identifier":"a3ba6666-18b8-47ea-aed3-99c4e2ffb20a","entryType":"SessionStatusChanged","entryPayload":{"entryType":"SessionStatusChanged","id":"a3ba6666-18b8-47ea-aed3-99c4e2ffb20a","conversationIdentifier":"57eedd4d-5eea-4e31-8f25-1e568bbf16cf","channelAddressIdentifier":"95997dc5-3041-4b64-9b2b-43e54d7312df","sessionStatusPrev":"Active","sessionEndedByRole":"Agent","sessionEndTime":1782113415000,"sessionStatus":"Ended","sessionStartTime":1782113315000,"sessionId":"0Mwds000007kpwN"},"sender":{"role":"System","appType":"conversation","subject":"0052o000009GmW3","clientIdentifier":null},"recipients":{"secondary":null,"hidden":null,"primary":null},"transcriptedTimestamp":1782113416617,"relatedRecords":[],"clientTimestamp":1782113416000,"clientDuration":0},{"identifier":"6855d021-6f25-4162-8fb8-284b79ff199a","entryType":"ParticipantChanged","entryPayload":{"entryType":"ParticipantChanged","id":"6855d021-6f25-4162-8fb8-284b79ff199a","entries":[{"operation":"remove","menuMetadata":null,"supportedModalities":null,"participant":{"role":"Agent","appType":"agent","subject":"0052o000009d7J9","clientIdentifier":""},"displayName":"Eirik F"}],"activeModalities":["Messaging"]},"sender":{"role":"System","appType":"conversation","subject":"0052o000009GmW3","clientIdentifier":null},"recipients":{"secondary":null,"hidden":null,"primary":null},"transcriptedTimestamp":1782113416671,"relatedRecords":[],"clientTimestamp":1782113416671,"clientDuration":0}]}';

        String jsonResponse =
            '{"conversationEntries":[' +
            '{' +
            '"clientDuration":0,"clientTimestamp":1732111810339,"identifier":"entry1",' +
            '"relatedRecords":["' +
            messagingSessionId +
            '"],' +
            '"sender":{"appType":"agent","role":"Agent","subject":"0052o000009d7J9"},' +
            '"transcriptedTimestamp":1732111810339,' +
            '"entryPayload":{"abstractMessage":{"staticContent":{"formatType":"Text","text":"Hei! Kan jeg hjelpe deg?"}}}' +
            '},' +
            '{' +
            '"clientDuration":0,"clientTimestamp":1732111810339,"identifier":"entry1",' +
            '"relatedRecords":["' +
            messagingSessionId +
            '"],' +
            '"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},' +
            '"transcriptedTimestamp":null,' +
            '"entryPayload":{"abstractMessage":{"staticContent":{"formatType":"Text","text":"Du kan hjelpe meg med dato!"}}}' +
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
            SELECT Id, CRM_Sent_Date__c
            FROM Message__c
            WHERE CRM_Thread__c = :thread.Id
        ];

        Assert.areEqual(2, messages.size(), 'Expected 2 messages created for the Text static content entries.');
        Assert.isNotNull(
            messages[0].CRM_Sent_Date__c,
            'Message sent date should be populated for the Text static content entry.'
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

    @IsTest
    static void createThreadMessages_NoWrapper() {
        NKS_ConversationEntryController.ConversationEntryWrapper wrapper = new NKS_ConversationEntryController.ConversationEntryWrapper();
        MessagingSession session = new MessagingSession();

        List<Application_Log__c> logsBefore = [SELECT Id FROM Application_Log__c];
        Test.startTest();
        NKS_ConversationEntryController.createThreadMessages(wrapper, session);
        Test.stopTest();
        List<Application_Log__c> logsAfter = [SELECT Id, Log_level__c, log_message__c FROM Application_Log__c];
        Assert.areEqual(0, logsBefore.size(), 'Expected no logs before execution');
        Assert.areEqual(1, logsAfter.size(), 'Expected 1 error log due to missing wrapper');
        Assert.isTrue(
            logsAfter[0].Log_message__c.contains('Wrapper not found '),
            'Expected error log message about missing wrapper'
        );
        Assert.isFalse(logsAfter[0].Log_level__c == 'Info', 'Expected log level to be higher than Info');
    }

    @IsTest
    static void createThreadMessages_NoThread() {
        NKS_ConversationEntryController.ConversationEntryWrapper wrapper = (NKS_ConversationEntryController.ConversationEntryWrapper) JSON.deserialize(
            '{"conversationEntries":[{"clientDuration":0,"clientTimestamp":1732111810339,"identifier":"entry1","messageText":"Frida: Hei! Jeg heter Frida og er NAVs chatbot.\\nFrida: Hva lurer du på?\\nBruker: menneske\\nFrida: Det er mange som trenger hjelp fra oss nå.","relatedRecords":["sessionId"],"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"transcriptedTimestamp":1732111810339}]}',
            NKS_ConversationEntryController.ConversationEntryWrapper.class
        );
        MessagingSession session = new MessagingSession();

        List<Application_Log__c> logsBefore = [SELECT Id FROM Application_Log__c];
        Test.startTest();
        NKS_ConversationEntryController.createThreadMessages(wrapper, session);
        Test.stopTest();
        List<Application_Log__c> logsAfter = [SELECT Id, Log_level__c, log_message__c FROM Application_Log__c];
        Assert.areEqual(0, logsBefore.size(), 'Expected no logs before execution');
        Assert.areEqual(1, logsAfter.size(), 'Expected 1 error log due to missing thread');
        Assert.isTrue(
            logsAfter[0].Log_message__c.contains('Thread not found '),
            'Expected error log message about missing thread'
        );
        Assert.isFalse(logsAfter[0].Log_level__c == 'Info', 'Expected log level to be higher than Info');
    }
}
