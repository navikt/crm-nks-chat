@isTest
public with sharing class nksChatView_Test {
    @TestSetup
    static void makeData() {
        User testUser = new User();
        testUser.CRM_NAV_Ident__c = 'Z654923';
        UTIL_TestDataFactory.createRecord(testUser);

        String botConversation = '22:15:14 - bot:\n';
        botConversation += 'Det er mange som vil snakke med oss nå. Hold chatten åpen og følg med, så svarer vi deg så snart vi kan.\n';
        botConversation += '22:15:14 - bot:\n';
        botConversation = 'Jeg setter deg over, et øyeblikk.\n';

        Case botCase = (Case) UTIL_TestDataFactory.createRecord(new Case(Description = botConversation));

        LiveChatTranscript transcript = new LiveChatTranscript(
            NKS_Journal_Entry_Created__c = true,
            Body = 'TESTBODY',
            CaseId = botCase.Id,
            NKS_Journal_Entry_ID__c = UTIL_TestDataFactory.generateRandomNumberString(10),
            CRM_Authentication_Status__c = 'Completed',
            NKS_Authentication_Timestamp__c = Datetime.now()
        );
        UTIL_TestDataFactory.createRecord(
            new Thread__c(CRM_Related_Object__c = (String) UTIL_TestDataFactory.createRecord(transcript).get('Id'))
        );
    }

    @isTest
    static void testGetThread() {
        LiveChatTranscript transcript = [SELECT Id FROM LiveChatTranscript LIMIT 1];

        Test.startTest();
        Thread__c testThread = nksChatView.getThread(transcript.Id);
        Test.stopTest();
        Assert.isNotNull(testThread.Id);
    }

    @isTest
    static void testGetThreadIdNoThread() {
        LiveChatVisitor visitor = [SELECT Id FROM LiveChatVisitor LIMIT 1];

        Test.startTest();
        Thread__c testThread = nksChatView.getThread(visitor.Id);
        Test.stopTest();
        Assert.isNull(testThread);
    }

    @isTest
    static void testGetChatbotMessage() {
        User user = [SELECT Id FROM User WHERE CRM_NAV_Ident__c = 'Z654923'];
        LiveChatTranscript transcript = [SELECT Id FROM LiveChatTranscript LIMIT 1];
        Test.startTest();
        String chatConversation = nksChatView.getChatbotMessage(transcript.Id, user.Id);
        Test.stopTest();
        Assert.isTrue(chatConversation == 'Det oppstod en feil');
    }

    @isTest
    static void testGetChatbotMessageNoUser() {
        User user = [SELECT Id FROM User WHERE CRM_NAV_Ident__c = 'Z654923'];
        LiveChatVisitor visitor = [SELECT Id FROM LiveChatVisitor LIMIT 1];
        Test.startTest();
        String chatConversation = nksChatView.getChatbotMessage(visitor.Id, user.Id);
        Test.stopTest();
        Assert.isTrue(chatConversation == 'Det oppstod en feil');
    }
}
