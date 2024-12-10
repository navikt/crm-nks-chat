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
    static void testConvertConversationEntries() {
        List<MessagingSession> messagingSessions = [
            SELECT Id, CRM_Authentication_Status__c
            FROM MessagingSession
            LIMIT 1
        ];
        messagingSessions[0].CRM_Authentication_Status__c = 'Completed';
        String messagingSessionId = messagingSessions[0].Id;

        String jsonResponse =
            '{' +
            '"conversationEntries":[{' +
            '"clientDuration":0,"clientTimestamp":1732111810339,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Frida: Første chatbotmelding fra Frida.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810339},' +
            '{"clientDuration":0,"clientTimestamp":1732111810439,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Tidligere melding fra bruker.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810439},' +
            '{"clientDuration":0,"clientTimestamp":1732111810607,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Tidligere melding fra bruker.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"Agent","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810607},' +
            '{"clientDuration":0,"clientTimestamp":1732111810707,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Velkommen til chat med NAV","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"System","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810707},' +
            '{"clientDuration":0,"clientTimestamp":1732111834844,"identifier":"adcf753e-bb2b-4a00-a6c6-7ebcf683df2c","messageText":"Melding fra veileder.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"agent","role":"Agent","subject":"0052o000009d7J9"},"serverReceivedTimestamp":1732111834844},' +
            '{"clientDuration":0,"clientTimestamp":1732111856855,"identifier":"ae84faf0-7cd5-4870-a860-5698c8508b7c","messageText":"Melding fra bruker.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111856855}' +
            ']}';

        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', jsonResponse, null));

        Test.startTest();
        update messagingSessions;
        Test.stopTest();

        Thread__c thread = [
            SELECT Id, Additional_Information__c
            FROM Thread__c
            WHERE CRM_Related_Object__c = :messagingSessionId
        ];
        List<Message__c> messages = [SELECT Id FROM Message__c WHERE CRM_Thread__c = :thread.Id];
        
        Assert.isTrue(messages.size() == 4, '4 messages should be inserted (including auth event message).');
        Assert.isTrue(
            thread.Additional_Information__c.contains('Frida: Første chatbotmelding fra Frida.'),
            'Fridalog should be added to the field.'
        );
    }

    @isTest
    static void testGetConversationEntryMessages() {
        List<MessagingSession> messagingSessions = [
            SELECT Id, Conversation.ConversationIdentifier
            FROM MessagingSession
            LIMIT 1
        ];

        String messagingSessionId = messagingSessions[0].Id;
        String conversationIdentifier = messagingSessions[0].Conversation.ConversationIdentifier;
        Long startTimestamp = 1732111834877L;
        Long endTimestamp = 1732111856833L;
        String queryDirection = 'FromStart';
        Integer recordLimit = 10;

        String jsonResponse =
            '{' +
            '"conversationEntries":[{' +
            '"clientDuration":0,"clientTimestamp":1732111810339,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Frida: Første chatbotmelding fra Frida.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810339},' +
            '{"clientDuration":0,"clientTimestamp":1732111810439,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Tidligere melding fra bruker.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810439},' +
            '{"clientDuration":0,"clientTimestamp":1732111810607,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Tidligere melding fra bruker.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"Agent","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810607},' +
            '{"clientDuration":0,"clientTimestamp":1732111810707,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Velkommen til chat med NAV","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"System","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810707},' +
            '{"clientDuration":0,"clientTimestamp":1732111834844,"identifier":"adcf753e-bb2b-4a00-a6c6-7ebcf683df2c","messageText":"Melding fra veileder.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"agent","role":"Agent","subject":"0052o000009d7J9"},"serverReceivedTimestamp":1732111834844},' +
            '{"clientDuration":0,"clientTimestamp":1732111856855,"identifier":"ae84faf0-7cd5-4870-a860-5698c8508b7c","messageText":"Melding fra bruker.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111856855}' +
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
}
