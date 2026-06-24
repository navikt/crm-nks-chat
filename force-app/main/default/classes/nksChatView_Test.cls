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

            MessagingEndUser msgEndUser_hasThread = new MessagingEndUser();
            msgEndUser_hasThread.Name = 'Messaging User With Thread';
            msgEndUser_hasThread.MessagingChannelId = msgChannel.Id;
            msgEndUser_hasThread.MessageType = 'EmbeddedMessaging';
            msgEndUser_hasThread.MessagingPlatformKey = 'TestChannel';
            insert msgEndUser_hasThread;

            MessagingSession msgSession_hasThread = new MessagingSession();
            msgSession_hasThread.MessagingEndUserId = msgEndUser_hasThread.Id;
            msgSession_hasThread.MessagingChannelId = msgChannel.Id;
            msgSession_hasThread.Status = 'Ended';
            msgSession_hasThread.EndTime = Datetime.now();
            insert msgSession_hasThread;

            Thread__c thread = new Thread__c(CRM_Related_Object__c = msgSession_hasThread.Id);
            insert thread;

            MessagingEndUser msgEndUser_noThread = new MessagingEndUser();
            msgEndUser_noThread.Name = 'Messaging User without Thread';
            msgEndUser_noThread.MessagingChannelId = msgChannel.Id;
            msgEndUser_noThread.MessageType = 'EmbeddedMessaging';
            msgEndUser_noThread.MessagingPlatformKey = 'TestChannel2';
            insert msgEndUser_noThread;

            MessagingSession msgSession_noThread = new MessagingSession();
            msgSession_noThread.MessagingEndUserId = msgEndUser_noThread.Id;
            msgSession_noThread.MessagingChannelId = msgChannel.Id;
            msgSession_noThread.Status = 'Ended';
            msgSession_noThread.EndTime = Datetime.now();
            insert msgSession_noThread;
        }
    }

    @isTest
    static void testGetThreadMessagingSession() {
        MessagingSession msgSession = [
            SELECT Id
            FROM MessagingSession
            WHERE MessagingEndUser.Name = 'Messaging User With Thread'
            LIMIT 1
        ];

        Test.startTest();
        Thread__c testThread = nksChatView.getThread(msgSession.Id);
        Test.stopTest();
        System.assert(testThread != null);
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
        MessagingEndUser user = [SELECT Id FROM MessagingEndUser WHERE Name = 'Messaging User With Thread'];
        MessagingSession msgSession = [
            SELECT Id
            FROM MessagingSession
            WHERE MessagingEndUser.Name = 'Messaging User With Thread'
            LIMIT 1
        ];
        Test.startTest();
        String chatConversation = nksChatView.getChatbotMessage(msgSession.Id, user.Id, false);
        Test.stopTest();
        Assert.isTrue(chatConversation == 'Det oppstod en feil');
    }

    @isTest
    static void testGetChatbotMessageNoUser() {
        createUser();
        User user = [SELECT Id FROM User WHERE CRM_NAV_Ident__c = 'Z654923'];
        LiveChatVisitor visitor = [SELECT Id FROM LiveChatVisitor LIMIT 1];
        Test.startTest();
        String chatConversation = nksChatView.getChatbotMessage(visitor.Id, user.Id, true);
        Test.stopTest();
        Assert.isTrue(chatConversation == 'Det oppstod en feil');
    }

    @isTest
    static void testGetThread_noMatchingThread_returnsNull() {
        MessagingSession msgSession = [
            SELECT Id
            FROM MessagingSession
            WHERE MessagingEndUser.Name = 'Messaging User without Thread'
            LIMIT 1
        ];

        Test.startTest();
        Thread__c result = nksChatView.getThread(msgSession.Id);
        Test.stopTest();

        Assert.isNull(result, 'Should return null when no thread is linked to the given ID');
    }

    @isTest
    static void testGetObjectInfo_withNullId_throwsAuraHandledException() {
        Test.startTest();
        try {
            nksChatView.getObjectInfo(null);
            Assert.fail('Expected AuraHandledException to be thrown');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'AuraHandledException should be thrown for null recordId');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetObjectInfo() {
        MessagingSession msgSession = [
            SELECT Id
            FROM MessagingSession
            WHERE MessagingEndUser.Name = 'Messaging User With Thread'
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
