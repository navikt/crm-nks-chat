@isTest
private class NKS_ChatTranscriptService_Test {
    @TestSetup
    static void makeData() {
        String botConversation = '22:15:14 - bot:\n';
        botConversation += 'Det er mange som vil snakke med oss nå. Hold chatten åpen og følg med, så svarer vi deg så snart vi kan.\n';
        botConversation += '22:15:14 - bot:\n';
        botConversation = 'Jeg setter deg over, et øyeblikk.\n';

        Case botCase = (Case) UTIL_TestDataFactory.createRecord(new Case(Description = botConversation));


        List<MessagingSession> transcripts = new List<MessagingSession>();
        for (Integer i = 0; i < 10; i++) {
            transcripts.add(
                new MessagingSession(
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
    }

    @isTest
    static void testStoreConversation() {
        MessagingSession transcript = [SELECT Id, NKS_Conversation__c FROM MessagingSession LIMIT 1];
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
        MessagingSession transcript = [SELECT Id, NKS_Conversation__c FROM MessagingSession LIMIT 1];
        MessagingSession result;
        Test.startTest();
        result = NKS_ChatTranscriptService.getChatTranscript(transcript.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGenerateAuthMessage() {
        MessagingSession transcript = [SELECT Id FROM MessagingSession LIMIT 1];
        Test.startTest();
        String result = NKS_ChatTranscriptService.generateAuthMessage(transcript.Id);
        Test.stopTest();
        String expectedText = NKS_ChatTranscriptService.authTexts.get('norwegian');

        Assert.areEqual(expectedText, result);
    }
}
