@IsTest
private class NKS_ConversationEntryController_Test {
    private static final Long FIRST_TIME = 1732111810339L;
    private static final Long SECOND_TIME = 1732111834844L;

    @TestSetup
    static void setup() {
        NKS_MessagingTestFixture.createSession('Ended', true);
    }

    private static MessagingSession session() {
        Id sessionId = [SELECT Id FROM MessagingSession LIMIT 1].Id;
        return NKS_MessagingTestFixture.hydratedSession(sessionId, 'fixture-conversation');
    }

    private static NKS_ConversationEntryController.ConversationEntry entry(
        String text,
        String role,
        String subject,
        Long timestamp
    ) {
        NKS_ConversationEntryController.ConversationEntry result = new NKS_ConversationEntryController.ConversationEntry();
        result.messageText = text;
        result.identifier = 'entry-' + timestamp;
        result.transcriptedTimestamp = timestamp;
        result.sender = new NKS_ConversationEntryController.Sender();
        result.sender.role = role;
        result.sender.subject = subject;
        return result;
    }

    private static String body(List<NKS_ConversationEntryController.ConversationEntry> entries) {
        return JSON.serialize(new Map<String, Object>{ 'conversationEntries' => entries });
    }

    private static NKS_RequestMock mockResponse(Integer statusCode, String responseBody) {
        NKS_RequestMock mock = new NKS_RequestMock(
            'callout:Conversation_Data_API/conversation-entries?conversationIdentifier=fixture-conversation&direction=FROMSTART&limit=1000',
            'GET',
            statusCode,
            responseBody
        );
        Test.setMock(HttpCalloutMock.class, mock);
        return mock;
    }

    private static void convert(List<MessagingSession> sessions) {
        NKS_ConversationEntryController.convertQueriedSessions(sessions, null, null, 'FROMSTART', 1000);
    }

    private static Thread__c thread(Id sessionId) {
        return [
            SELECT Id, CRM_isActive__c, CRM_Closed_Date__c, CRM_Additional_Information__c
            FROM Thread__c
            WHERE CRM_Related_Object__c = :sessionId
            LIMIT 1
        ];
    }

    private static List<Message__c> messages(Id threadId) {
        return [
            SELECT
                CRM_Message_Text__c,
                CRM_Type__c,
                CRM_From_User__c,
                CRM_From_NAV_Unit__c,
                CRM_From_Contact__c,
                CRM_Sent_Date__c,
                CRM_Read__c
            FROM Message__c
            WHERE CRM_Thread__c = :threadId
            ORDER BY CRM_Sent_Date__c ASC NULLS FIRST
        ];
    }

    @IsTest
    static void conversionPreservesMessagesSendersTimestampsAndThreadMetadata() {
        Contact contact = (Contact) UTIL_TestDataFactory.createRecord(new Contact());
        MessagingEndUser endUser = [SELECT Id FROM MessagingEndUser LIMIT 1];
        endUser.ContactId = contact.Id;
        update endUser;
        MessagingSession session = session();
        session.NKS_Authentication_Timestamp__c = Datetime.newInstance(FIRST_TIME - 1000);
        User agent = [SELECT Id, Department FROM User WHERE Id = :UserInfo.getUserId()];
        NKS_ConversationEntryController.navUserInfoByUserId.put(String.valueOf(agent.Id).left(15), agent);
        NKS_RequestMock mock = mockResponse(
            200,
            body(
                new List<NKS_ConversationEntryController.ConversationEntry>{
                    entry('NavBot: Hello\nBruker: human\nNavBot: Connecting', 'System', null, FIRST_TIME),
                    entry('Welcome to chat with NAV. You\'re chatting with Alex.', 'System', null, FIRST_TIME),
                    entry('Veileder: Agent &amp; reply', 'Agent', agent.Id, SECOND_TIME),
                    entry('Bruker: Customer reply', 'EndUser', null, SECOND_TIME + 1),
                    entry('---conversation terminated by end-user---', 'EndUser', null, SECOND_TIME + 2)
                }
            )
        );
        Test.startTest();
        convert(new List<MessagingSession>{ session });
        Test.stopTest();
        Assert.areEqual(1, mock.calls);
        Thread__c thread = thread(session.Id);
        List<Message__c> messages = messages(thread.Id);
        Assert.areEqual(4, messages.size());
        Assert.areEqual('Event', messages[0].CRM_Type__c);
        Assert.areEqual('Started authenticated chat', messages[0].CRM_Message_Text__c);
        Assert.areEqual(session.NKS_Authentication_Timestamp__c, messages[0].CRM_Sent_Date__c);
        Assert.areEqual('Welcome to chat with NAV. You\'re chatting with Alex.', messages[1].CRM_Message_Text__c);
        Assert.areEqual(agent.Id, messages[1].CRM_From_User__c, 'Welcome inherits the following agent');
        Assert.areEqual('Agent & reply', messages[2].CRM_Message_Text__c);
        Assert.areEqual(agent.Id, messages[2].CRM_From_User__c);
        Assert.areEqual(agent.Department, messages[2].CRM_From_NAV_Unit__c);
        Assert.areEqual(Datetime.newInstance(SECOND_TIME), messages[2].CRM_Sent_Date__c);
        Assert.areEqual('Customer reply', messages[3].CRM_Message_Text__c);
        Assert.areEqual(contact.Id, messages[3].CRM_From_Contact__c);
        Assert.areEqual(true, messages[3].CRM_Read__c);
        Assert.areEqual('NavBot: Hello\nBruker: human\nNavBot: Connecting', thread.CRM_Additional_Information__c);
        Assert.areEqual(false, thread.CRM_isActive__c);
        Assert.isNotNull(thread.CRM_Closed_Date__c);
        Assert.areEqual(0, Limits.getQueueableJobs(), 'Conversion does not implicitly delete participants');
    }

    @IsTest
    static void richLinkAndTextPayloadsUseTranscriptTimestampNotClientTimestamp() {
        MessagingSession session = session();
        NKS_RequestMock mock = mockResponse(
            200,
            '{"conversationEntries":[' +
                '{"clientTimestamp":1,"transcriptedTimestamp":1732111810339,"sender":{"role":"Agent"},' +
                '"entryPayload":{"abstractMessage":{"staticContent":{"formatType":"RichLink","linkItem":{"url":"https://www.nav.no"}}}}},' +
                '{"clientTimestamp":2,"transcriptedTimestamp":1732111834844,"sender":{"role":"EndUser"},' +
                '"entryPayload":{"abstractMessage":{"staticContent":{"formatType":"Text","text":"Customer text"}}}}]}'
        );
        Test.startTest();
        convert(new List<MessagingSession>{ session });
        Test.stopTest();
        Assert.areEqual(1, mock.calls);
        List<Message__c> messages = messages(thread(session.Id).Id);
        Assert.areEqual(2, messages.size());
        Assert.areEqual('https://www.nav.no', messages[0].CRM_Message_Text__c);
        Assert.areEqual('Customer text', messages[1].CRM_Message_Text__c);
        Assert.areEqual(Datetime.newInstance(FIRST_TIME), messages[0].CRM_Sent_Date__c);
        Assert.areEqual(Datetime.newInstance(SECOND_TIME), messages[1].CRM_Sent_Date__c);
    }

    @IsTest
    static void normalizationHandlesMissingSenderBlankTextAndMultilineTranscript() {
        MessagingSession session = session();
        session.EndUserLanguage = 'nb_NO';
        session.NKS_Authentication_Timestamp__c = Datetime.newInstance(FIRST_TIME - 1);
        NKS_ConversationEntryController.ConversationEntry noSender = entry('Unknown sender', null, null, FIRST_TIME);
        noSender.sender = null;
        mockResponse(
            200,
            body(
                new List<NKS_ConversationEntryController.ConversationEntry>{
                    entry(null, 'Agent', null, null),
                    entry('  ', 'Agent', null, null),
                    entry('Before agent', 'EndUser', null, FIRST_TIME),
                    noSender,
                    entry('NavBot: Intro\r\n\r\nVeileder: Hello\r\nBruker: Reply', 'System', null, SECOND_TIME),
                    entry('Ignored system text', 'System', null, null),
                    entry('No timestamp', 'Agent', null, null)
                }
            )
        );
        Test.startTest();
        convert(new List<MessagingSession>{ session });
        Test.stopTest();
        Thread__c thread = thread(session.Id);
        Test.getEventBus().deliver();
        Assert.areEqual(
            'Bruker: Before agent\nNavBot: Unknown sender\nNavBot: Intro',
            thread.CRM_Additional_Information__c,
            JSON.serialize([SELECT Log_message__c FROM Application_Log__c])
        );
        List<Message__c> messages = messages(thread.Id);
        Assert.areEqual(4, messages.size());
        Assert.areEqual('Startet innlogget chat', messages[0].CRM_Message_Text__c);
        Set<String> texts = new Set<String>();
        for (Message__c message : messages) {
            texts.add(message.CRM_Message_Text__c);
        }
        Assert.isTrue(texts.contains('Hello'));
        Assert.isTrue(texts.contains('Reply'));
        Assert.isTrue(texts.contains('No timestamp'));
    }

    @IsTest
    static void norwegianWelcomeWithoutSenderStartsChatButEndUserWelcomeDoesNot() {
        MessagingSession session = session();
        NKS_ConversationEntryController.ConversationEntry welcome = entry(
            'Velkommen til chat med NAV. Du snakker med Alex.',
            null,
            null,
            SECOND_TIME
        );
        welcome.sender = null;
        mockResponse(
            200,
            body(
                new List<NKS_ConversationEntryController.ConversationEntry>{
                    entry(welcome.messageText, 'EndUser', null, FIRST_TIME),
                    welcome
                }
            )
        );
        Test.startTest();
        convert(new List<MessagingSession>{ session });
        Test.stopTest();
        Thread__c thread = thread(session.Id);
        Assert.areEqual('Bruker: ' + welcome.messageText, thread.CRM_Additional_Information__c);
        List<Message__c> messages = messages(thread.Id);
        Assert.areEqual(1, messages.size());
        Assert.areEqual(welcome.messageText, messages[0].CRM_Message_Text__c);
        Assert.isNull(messages[0].CRM_From_User__c);
    }

    @IsTest
    static void repeatedConversionPreservesCurrentAppendBehavior() {
        MessagingSession session = session();
        mockResponse(
            200,
            body(
                new List<NKS_ConversationEntryController.ConversationEntry>{
                    entry('Agent text', 'Agent', null, FIRST_TIME)
                }
            )
        );
        Test.startTest();
        convert(new List<MessagingSession>{ session });
        System.enqueueJob(new RepeatConversionJob(session));
        Test.stopTest();
        List<Message__c> messages = messages(thread(session.Id).Id);
        Assert.areEqual(
            2,
            messages.size(),
            'Repeated conversion currently appends: ' + JSON.serialize([SELECT Log_message__c FROM Application_Log__c])
        );
        Assert.areEqual(messages[0].CRM_Message_Text__c, messages[1].CRM_Message_Text__c);
        Assert.areEqual(messages[0].CRM_Sent_Date__c, messages[1].CRM_Sent_Date__c);
    }

    private class RepeatConversionJob implements Queueable, Database.AllowsCallouts {
        private MessagingSession session;
        RepeatConversionJob(MessagingSession session) {
            this.session = session;
        }
        public void execute(QueueableContext context) {
            convert(new List<MessagingSession>{ session });
        }
    }

    private static void assertFailedResponse(Integer statusCode, String responseBody, String logText) {
        MessagingSession session = session();
        NKS_RequestMock mock = mockResponse(statusCode, responseBody);
        Test.startTest();
        convert(new List<MessagingSession>{ session });
        Test.stopTest();
        Assert.areEqual(1, mock.calls);
        Assert.areEqual(0, messages(thread(session.Id).Id).size());
        Assert.isNull(thread(session.Id).CRM_Closed_Date__c);
        NKS_MessagingTestFixture.assertLogged(logText);
    }

    @IsTest
    static void malformedResponseIsLogged() {
        assertFailedResponse(200, '{not-json', 'Session callout failed');
    }
    @IsTest
    static void emptyResponseIsLogged() {
        assertFailedResponse(200, '{"conversationEntries":[]}', 'Wrapper not found');
    }
    @IsTest
    static void nullResponseIsLogged() {
        assertFailedResponse(200, 'null', 'Wrapper not found');
    }
    @IsTest
    static void missingEntriesIsLogged() {
        assertFailedResponse(200, '{}', 'Wrapper not found');
    }
    @IsTest
    static void httpErrorIsLogged() {
        assertFailedResponse(503, 'Unavailable', 'Status Code: 503');
    }

    private class MixedResponseMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            Assert.areEqual('GET', request.getMethod());
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody(
                request.getEndpoint().contains('broken-conversation')
                    ? '{broken'
                    : body(
                          new List<NKS_ConversationEntryController.ConversationEntry>{
                              entry('Successful session', 'Agent', null, FIRST_TIME)
                          }
                      )
            );
            return response;
        }
    }

    @IsTest
    static void failedSessionDoesNotPreventOtherSessionConversion() {
        MessagingSession first = session();
        MessagingSession second = NKS_MessagingTestFixture.createSession('Ended', true);
        second = NKS_MessagingTestFixture.hydratedSession(second.Id, 'broken-conversation');
        Test.setMock(HttpCalloutMock.class, new MixedResponseMock());
        Test.startTest();
        convert(new List<MessagingSession>{ second, first });
        Test.stopTest();
        Assert.areEqual(0, messages(thread(second.Id).Id).size());
        Assert.areEqual(1, messages(thread(first.Id).Id).size());
        Assert.areEqual('Successful session', messages(thread(first.Id).Id)[0].CRM_Message_Text__c);
        NKS_MessagingTestFixture.assertLogged('Session callout failed | sessionId=' + second.Id);
    }

    @IsTest
    static void missingThreadIsLogged() {
        MessagingSession session = session();
        delete thread(session.Id);
        mockResponse(
            200,
            body(
                new List<NKS_ConversationEntryController.ConversationEntry>{ entry('Agent', 'Agent', null, FIRST_TIME) }
            )
        );
        Test.startTest();
        convert(new List<MessagingSession>{ session });
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM Message__c]);
        NKS_MessagingTestFixture.assertLogged('Thread not found');
    }

    @IsTest
    static void invalidMessageRelationshipLogsInsertFailure() {
        MessagingSession session = session();
        Map<String, Object> fields = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(session));
        fields.put('EndUserContactId', session.Id);
        session = (MessagingSession) JSON.deserialize(JSON.serialize(fields), MessagingSession.class);
        mockResponse(
            200,
            body(
                new List<NKS_ConversationEntryController.ConversationEntry>{
                    entry('Agent text', 'Agent', null, FIRST_TIME),
                    entry('Invalid contact', 'EndUser', null, SECOND_TIME)
                }
            )
        );
        Test.startTest();
        convert(new List<MessagingSession>{ session });
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM Message__c], 'The message insert is atomic');
        NKS_MessagingTestFixture.assertLogged('.insertMessages ERROR');
    }

    @IsTest
    static void invalidTimestampDoesNotPreventOtherSessionConversion() {
        MessagingSession first = session();
        MessagingSession second = NKS_MessagingTestFixture.createSession('Ended', true);
        second = NKS_MessagingTestFixture.hydratedSession(second.Id, 'invalid-timestamp');
        Test.setMock(HttpCalloutMock.class, new InvalidTimestampMock());
        Test.startTest();
        convert(new List<MessagingSession>{ second, first });
        Test.stopTest();
        Assert.areEqual(1, messages(thread(first.Id).Id).size());
        Assert.areEqual(0, messages(thread(second.Id).Id).size());
        NKS_MessagingTestFixture.assertLogged('.insertMessages ERROR');
    }

    private class InvalidTimestampMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody(
                body(
                    new List<NKS_ConversationEntryController.ConversationEntry>{
                        entry(
                            'Agent text',
                            'Agent',
                            null,
                            request.getEndpoint().contains('invalid-timestamp') ? 9223372036854775807L : FIRST_TIME
                        )
                    }
                )
            );
            return response;
        }
    }

    @IsTest
    static void threadDeletedBeforeUpdateLogsFailure() {
        MessagingSession session = session();
        Thread__c deletedThread = thread(session.Id);
        delete deletedThread;
        Test.startTest();
        NKS_ConversationEntryController.updateThread(deletedThread);
        NKS_ConversationEntryController.convertConversationEntries(null, null, null, null, null);
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM Thread__c WHERE Id = :deletedThread.Id]);
        NKS_MessagingTestFixture.assertLogged('.updateThread ERROR | threadId=' + deletedThread.Id);
    }

    @IsTest
    static void inMemoryWrapperSkipsNullEntries() {
        MessagingSession session = session();
        NKS_ConversationEntryController.ConversationEntryWrapper wrapper = new NKS_ConversationEntryController.ConversationEntryWrapper();
        wrapper.conversationEntries = new List<NKS_ConversationEntryController.ConversationEntry>{
            null,
            entry('Agent text', 'Agent', null, FIRST_TIME)
        };
        Test.startTest();
        NKS_ConversationEntryController.createThreadMessages(wrapper, session);
        Test.stopTest();
        Assert.areEqual(1, messages(thread(session.Id).Id).size());
    }

    @IsTest
    static void missingRealConversationIdentifierIsLoggedWithoutCallout() {
        MessagingSession session = [SELECT Id FROM MessagingSession LIMIT 1];
        MyTriggers.disable(NKS_MessagingSessionHandler.class);
        session.CRM_Authentication_Status__c = 'Completed';
        update session;
        Test.startTest();
        NKS_ConversationEntryController.convertConversationEntries(
            new List<MessagingSession>{ session },
            null,
            null,
            null,
            null
        );
        Assert.areEqual(0, Limits.getCallouts());
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM Message__c]);
        NKS_MessagingTestFixture.assertLogged('conversationIdentifier is null');
    }

    @IsTest
    static void nullEmptyUnpersistedAndUnauthenticatedInputsDoNothing() {
        MessagingSession session = session();
        session.CRM_Authentication_Status__c = 'Not Started';
        Test.startTest();
        NKS_ConversationEntryController.convertConversationEntries(null, null, null, null, null);
        NKS_ConversationEntryController.convertConversationEntries(
            new List<MessagingSession>(),
            null,
            null,
            null,
            null
        );
        NKS_ConversationEntryController.convertConversationEntries(
            new List<MessagingSession>{ null, new MessagingSession() },
            null,
            null,
            null,
            null
        );
        convert(new List<MessagingSession>{ session });
        Assert.areEqual(0, Limits.getCallouts());
        Assert.areEqual(0, Limits.getQueueableJobs());
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM Message__c]);
    }

    @IsTest
    static void participantCleanupEnqueuesExactDeleteRequest() {
        MessagingSession session = [SELECT Id, MessagingEndUserId FROM MessagingSession LIMIT 1];
        Test.setMock(
            HttpCalloutMock.class,
            new NKS_RequestMock(
                'callout:Conversation_Data_API/conversation-participants?participantEntityId=' +
                    session.MessagingEndUserId +
                    '&cascadeLevel=FULL_CASCADE',
                'DELETE',
                200,
                '{}'
            )
        );
        Test.startTest();
        NKS_ConversationEntryController.retryDeleteParticipantData(new List<String>{ session.MessagingEndUserId });
        Assert.areEqual(1, Limits.getQueueableJobs());
        NKS_ConversationEntryController.deleteSessionDataAndEnqueueCallout(new Set<Id>(), new List<String>());
        Assert.areEqual(1, Limits.getQueueableJobs());
        Test.stopTest();
        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'NKS_DeleteConvParticipantDataQueueable'
        ];
        Assert.areEqual('Completed', job.Status);
        Assert.areEqual(0, job.NumberOfErrors);
    }
}
