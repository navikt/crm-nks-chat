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
            MessagingChannel objMsgChannel = new MessagingChannel();
            objMsgChannel.MasterLabel = 'TestChannel';
            objMsgChannel.DeveloperName = 'TestChannel';
            objMsgChannel.IsActive = true;
            objMsgChannel.MessageType = 'Text';
            objMsgChannel.MessagingPlatformKey = 'TestChannel';
            insert objMsgChannel;

            MessagingEndUser objMsgUser = new MessagingEndUser();
            objMsgUser.Name = 'Messaging User';
            objMsgUser.MessagingChannelId = objMsgChannel.Id;
            objMsgUser.MessageType = 'EmbeddedMessaging';
            objMsgUser.MessagingPlatformKey = 'TestChannel';
            insert objMsgUser;

            MessagingSession objSession = new MessagingSession();
            objSession.MessagingEndUserId = objMsgUser.Id;
            objSession.MessagingChannelId = objMsgChannel.Id;
            objSession.Status = 'Active';
            objSession.Queue_Name__c = 'NKS_Messaging_Arbeid';
            insert objSession;
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
        Assert.areEqual('Active', result.Status, 'The Status field should match');
    }

    @isTest
    static void testGenerateAuthMessageMessagingSessionEnglish() {
        MessagingSession testSession = [
            SELECT Id, CRM_Language__c
            FROM MessagingSession
            LIMIT 1
        ];
        testSession.CRM_Language__c = 'en_US';
        update testSession;

        Test.startTest();
        String result = NKS_ChatTranscriptService.generateAuthMessage(testSession.Id);
        Test.stopTest();

        String expectedText = NKS_ChatTranscriptService.authTexts.get('english');
        Assert.areEqual(expectedText, result);
    }
}
