@isTest
private class NKS_ChatTranscriptService_Test {
    @TestSetup
    static void makeData() {
        String botConversation = '22:15:14 - bot:\n';
        botConversation += 'Det er mange som vil snakke med oss nå. Hold chatten åpen og følg med, så svarer vi deg så snart vi kan.\n';
        botConversation += '22:15:14 - bot:\n';
        botConversation = 'Jeg setter deg over, et øyeblikk.\n';

        Case botCase = (Case) UTIL_TestDataFactory.createRecord(new Case(Description = botConversation));

        List<LiveChatTranscript> transcripts = new List<LiveChatTranscript>();
        for (Integer i = 0; i < 10; i++) {
            transcripts.add(
                new LiveChatTranscript(
                    NKS_Journal_Entry_Created__c = true,
                    Body = 'TESTBODY',
                    CaseId = botCase.Id,
                    NKS_Journal_Entry_ID__c = UTIL_TestDataFactory.generateRandomNumberString(10),
                    CRM_Authentication_Status__c = 'Completed',
                    NKS_Authentication_Timestamp__c = Datetime.now()
                )
            );
        }
        UTIL_TestDataFactory.createRecord(
            new Thread__c(
                CRM_Related_Object__c = (String) UTIL_TestDataFactory.createRecordList(transcripts)[0].get('Id')
            )
        );

        User testUser = new User();
        testUser.CRM_NAV_Ident__c = 'Z999998';
        UTIL_TestDataFactory.createRecord(testUser);

        System.runAs(testUser) {
            MessagingSession objSession = NKS_MessagingTestFixture.createSession('New', false);
            objSession.Queue_Name__c = 'NKS_Messaging_Arbeid';
            update objSession;
        }
    }

    @isTest
    static void testStoreConversation() {
        LiveChatTranscript transcript = [SELECT Id, NKS_Conversation__c FROM LiveChatTranscript LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE CRM_NAV_Ident__c = 'Z999998'];

        StaticResource testConversation = [
            SELECT Id, Body
            FROM StaticResource
            WHERE Name = 'NKS_Chat_Conversation_Mock'
        ];
        String conversation = testConversation.Body.toString();

        Test.startTest();
        NKS_ChatTranscriptService.navIdentUserMap.clear();
        NKS_ChatTranscriptService.navIdentUserMap.put('Z999998', testUser);
        NKS_ChatTranscriptService.storeConversation(transcript.Id, conversation);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Thread__c WHERE CRM_Related_Object__c = :transcript.Id]);
    }

    @isTest
    static void testGetChatTranscript() {
        LiveChatTranscript transcript = [SELECT Id, NKS_Conversation__c FROM LiveChatTranscript LIMIT 1];
        LiveChatTranscript result;
        Test.startTest();
        result = NKS_ChatTranscriptService.getChatTranscript(transcript.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGenerateAuthMessage() {
        LiveChatTranscript transcript = [SELECT Id FROM LiveChatTranscript LIMIT 1];
        Test.startTest();
        String result = NKS_ChatTranscriptService.generateAuthMessage(transcript.Id);
        Test.stopTest();
        String expectedText = NKS_ChatTranscriptService.authTexts.get('norwegian');

        Assert.areEqual(expectedText, result);
    }

    @isTest
    static void testGetMessagingSession() {
        MessagingSession testSession = [
            SELECT Id
            FROM MessagingSession
            LIMIT 1
        ];

        Test.startTest();
        MessagingSession result = NKS_ChatTranscriptService.getMessagingSession(testSession.Id);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'The result should not be null');
        Assert.areEqual('NKS_Messaging_Arbeid', result.Queue_Name__c, 'The Queue_Name__c field should match');
        Assert.areEqual('New', result.Status, 'The Status field should match');
    }

    @isTest
    static void testGenerateAuthMessageMessagingSessionFallback() {
        MessagingSession testSession = [
            SELECT Id
            FROM MessagingSession
            LIMIT 1
        ];

        Test.startTest();
        String result = NKS_ChatTranscriptService.generateAuthMessage(testSession.Id);
        Test.stopTest();

        String expectedText = NKS_ChatTranscriptService.authTexts.get('norwegian');
        Assert.areEqual(expectedText, result);
    }

    @IsTest
    static void messageOrderingTypesAndTransferLanguages() {
        NKS_ChatTranscriptService.Message first = (NKS_ChatTranscriptService.Message) JSON.deserialize(
            '{"timestamp":"1000","type":"agent","name":"Alex (Z999998)","content":"Hello"}',
            NKS_ChatTranscriptService.Message.class
        );
        NKS_ChatTranscriptService.Message second = (NKS_ChatTranscriptService.Message) JSON.deserialize(
            '{"timestamp":"2000","type":"OperatorTransferred","name":"Sam"}',
            NKS_ChatTranscriptService.Message.class
        );
        Assert.areEqual(-1, first.compareTo(second));
        Assert.areEqual(1, second.compareTo(first));
        Assert.areEqual(0, first.compareTo(first));
        Assert.areEqual(true, first.isAgentMessage());
        Assert.areEqual(false, second.isAgentMessage());
        Assert.areEqual('Message', first.getThreadMessageType());
        Assert.areEqual('Event', second.getThreadMessageType());
        second.language = 'en_US';
        Assert.areEqual('Transferred to Sam', second.getTransfertext());
        second.language = 'nb_NO';
        Assert.areEqual('Overført til Sam', second.getTransfertext());
    }

    @IsTest
    static void unauthenticatedTranscriptDoesNotCreateMessages() {
        LiveChatTranscript transcript = [SELECT Id, NKS_Authentication_Timestamp__c FROM LiveChatTranscript LIMIT 1];
        transcript.NKS_Authentication_Timestamp__c = null;
        update transcript;
        Test.startTest();
        NKS_ChatTranscriptService.storeConversation(transcript.Id, '[]');
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM Message__c]);
    }

    @IsTest
    static void invalidTranscriptThrows() {
        Id wrongId = [SELECT Id FROM MessagingSession LIMIT 1].Id;
        Test.startTest();
        try {
            NKS_ChatTranscriptService.getChatTranscript(wrongId);
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            Assert.areEqual('System.AuraHandledException', ex.getTypeName());
        }
        Test.stopTest();
    }

    @IsTest
    static void invalidMessagingSessionThrows() {
        Id wrongId = [SELECT Id FROM LiveChatTranscript LIMIT 1].Id;
        Test.startTest();
        try {
            NKS_ChatTranscriptService.getMessagingSession(wrongId);
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            Assert.areEqual('System.AuraHandledException', ex.getTypeName());
        }
        Test.stopTest();
    }

    @IsTest
    static void missingAuthenticationMessageIdUsesNorwegianFallback() {
        Test.startTest();
        String actual = NKS_ChatTranscriptService.generateAuthMessage(null);
        Test.stopTest();
        Assert.areEqual(NKS_ChatTranscriptService.authTexts.get('norwegian'), actual);
    }

    @IsTest
    static void storeConversationPersistsExactMessagesSendersAndClosedThread() {
        LiveChatTranscript transcript = [SELECT Id, NKS_Authentication_Timestamp__c FROM LiveChatTranscript LIMIT 1];
        Datetime authTime = Datetime.now().addMinutes(-5);
        transcript.NKS_Authentication_Timestamp__c = authTime;
        update transcript;
        Thread__c thread = [SELECT Id FROM Thread__c WHERE CRM_Related_Object__c = :transcript.Id];
        Contact contact = (Contact) UTIL_TestDataFactory.createRecord(new Contact());
        thread.CRM_Contact__c = contact.Id;
        update thread;
        User agent = [SELECT Id, Department FROM User WHERE CRM_NAV_Ident__c = 'Z999998'];
        NKS_ChatTranscriptService.navIdentUserMap.clear();
        NKS_ChatTranscriptService.navIdentUserMap.put('Z999998', agent);
        Long timestamp = authTime.addMinutes(1).getTime();
        String conversation = JSON.serialize(
            new List<Object>{
                new Map<String, Object>{
                    'content' => 'Customer text',
                    'name' => 'Customer',
                    'type' => 'EndUser',
                    'timestamp' => String.valueOf(timestamp + 1000)
                },
                new Map<String, Object>{
                    'content' => 'Agent text',
                    'name' => 'Agent (Z999998)',
                    'type' => 'Agent',
                    'timestamp' => String.valueOf(timestamp)
                },
                new Map<String, Object>{
                    'content' => 'Transfer',
                    'name' => 'Sam',
                    'type' => 'OperatorTransferred',
                    'timestamp' => String.valueOf(timestamp + 2000)
                }
            }
        );
        Test.startTest();
        NKS_ChatTranscriptService.storeConversation(transcript.Id, conversation);
        NKS_ChatTranscriptService.storeConversation(transcript.Id, conversation);
        Test.stopTest();
        List<Message__c> messages = [
            SELECT
                CRM_Message_Text__c,
                CRM_Type__c,
                CRM_Sent_Date__c,
                CRM_From_User__c,
                CRM_From_NAV_Unit__c,
                CRM_From_Contact__c
            FROM Message__c
            WHERE CRM_Thread__c = :thread.Id
            ORDER BY CRM_Sent_Date__c
        ];
        Assert.areEqual(4, messages.size(), 'Repeated EndEvents must not duplicate transcript messages');
        Assert.areEqual('Startet innlogget chat', messages[0].CRM_Message_Text__c);
        Assert.areEqual(authTime, messages[0].CRM_Sent_Date__c);
        Assert.areEqual('Agent text', messages[1].CRM_Message_Text__c);
        Assert.areEqual(agent.Id, messages[1].CRM_From_User__c);
        Assert.areEqual(agent.Department, messages[1].CRM_From_NAV_Unit__c);
        Assert.areEqual(Datetime.newInstance(timestamp), messages[1].CRM_Sent_Date__c);
        Assert.areEqual('Customer text', messages[2].CRM_Message_Text__c);
        Assert.areEqual(contact.Id, messages[2].CRM_From_Contact__c);
        Assert.areEqual('Event', messages[3].CRM_Type__c);
        Assert.areEqual('Overført til Sam', messages[3].CRM_Message_Text__c);
        thread = [SELECT CRM_isActive__c, CRM_Closed_Date__c FROM Thread__c WHERE Id = :thread.Id];
        Assert.areEqual(false, thread.CRM_isActive__c);
        Assert.isNotNull(thread.CRM_Closed_Date__c);
    }
}
