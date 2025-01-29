@isTest
public with sharing class nksChatView_Test {
    @TestSetup
    static void makeData() {
        /*
            CHAT TRANSCRIPT
        */
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

        /*
            MESSAGING SESSION
        */
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
    static void testGetThreadIdChatTranscript() {
        LiveChatTranscript transcript = [SELECT Id FROM LiveChatTranscript LIMIT 1];

        Test.startTest();
        Id threadId = nksChatView.getThreadId(transcript.Id);
        Test.stopTest();
        System.assert(threadId != null);
    }

    @isTest
    static void testGetThreadIdMessagingSession() {
        MessagingSession msgSession = [
            SELECT Id
            FROM MessagingSession
            LIMIT 1
        ];

        Test.startTest();
        Id threadId = nksChatView.getThreadId(msgSession.Id);
        Test.stopTest();
        System.assert(threadId != null);
    }

    @isTest
    static void testGetThreadIdNoThread() {
        LiveChatVisitor visitor = [SELECT Id FROM LiveChatVisitor LIMIT 1];

        Test.startTest();
        Id threadId = nksChatView.getThreadId(visitor.Id);
        Test.stopTest();
        System.assert(threadId == null);
    }

    @isTest
    static void testGetChatbotMessageChatTranscript() {
        createUser();
        User user = [SELECT Id FROM User WHERE CRM_NAV_Ident__c = 'Z654923'];
        LiveChatTranscript transcript = [SELECT Id FROM LiveChatTranscript LIMIT 1];
        Test.startTest();
        String chatConversation = nksChatView.getChatbotMessage(transcript.Id, user.Id, true);
        Test.stopTest();
        System.assert(chatConversation == 'Det oppstod en feil');
    }

    @isTest
    static void testGetChatbotMessageMessagingSession() {
        createUser();
        MessagingEndUser user = [SELECT Id FROM MessagingEndUser WHERE Name = 'Messaging User'];
        MessagingSession msgSession = [
            SELECT Id
            FROM MessagingSession
            LIMIT 1
        ];
        Test.startTest();
        String chatConversation = nksChatView.getChatbotMessage(msgSession.Id, user.Id, false);
        Test.stopTest();
        System.assert(chatConversation == 'Det oppstod en feil');
    }

    @isTest
    static void testGetChatbotMessageNoUser() {
        createUser();
        User user = [SELECT Id FROM User WHERE CRM_NAV_Ident__c = 'Z654923'];
        LiveChatVisitor visitor = [SELECT Id FROM LiveChatVisitor LIMIT 1];
        Test.startTest();
        String chatConversation = nksChatView.getChatbotMessage(visitor.Id, user.Id, true);
        Test.stopTest();
        System.assert(chatConversation == 'Det oppstod en feil');
    }

    @isTest
    static void testGetObjectInfo() {
        MessagingSession msgSession = [
            SELECT Id
            FROM MessagingSession
            LIMIT 1
        ];
        Test.startTest();
        String objectType = nksChatView.getObjectInfo(msgSession.Id);
        Test.stopTest();
        System.assert(objectType == 'MessagingSession');
    }

    static void createUser() {
        User testUser = new User();
        testUser.CRM_NAV_Ident__c = 'Z654923';
        UTIL_TestDataFactory.createRecord(testUser);
    }
}
