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
            SELECT Id, Status, Conversation.ConversationIdentifier, CRM_Authentication_Status__c
            FROM MessagingSession
            LIMIT 1
        ];
        messagingSessions[0].CRM_Authentication_Status__c = 'Completed';
        String messagingSessionId = messagingSessions[0].Id;

        String jsonResponse =
            '{"conversationEntries":[{"clientDuration":0,"clientTimestamp":1732111856833,"identifier":"ae84faf0-7cd5-4870-a860-5698c8508b7c","messageText":"Melding fra bruker.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111856855},{"clientDuration":0,"clientTimestamp":1732111834877,"identifier":"adcf753e-bb2b-4a00-a6c6-7ebcf683df2c","messageText":"Melding fra veileder.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"agent","role":"Agent","subject":"0052o000009d7J9"},"serverReceivedTimestamp":1732111834344},{"clientDuration":0,"clientTimestamp":1732111810498,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Welcome to chat with NAV.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"System","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810607},{"clientDuration":0,"clientTimestamp":1732111810498,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Chatbotmelding.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810607},{"clientDuration":0,"clientTimestamp":1732111810498,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Tidligere melding fra veileder.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"Agent","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810607},{"clientDuration":0,"clientTimestamp":1732111810498,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Tidligere melding fra bruker.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810337},{"clientDuration":0,"clientTimestamp":1732111810498,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Tidligere chatbotmelding.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810339}]}';

        Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, 'OK', jsonResponse, null));

        Test.startTest();
        update messagingSessions;
        Test.stopTest();

        String threadId = [SELECT Id FROM Thread__c WHERE CRM_Related_Object__c = :messagingSessionId].Id;
        List<Message__c> messages = [SELECT Id, CRM_Message_Text__c FROM Message__c WHERE CRM_Thread__c = :threadId];
        Assert.isTrue(
            messages.size() == 3,
            '3 messages should be inserted. 1 for chatbot history and 2 for user/advisor.'
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
            '{"conversationEntries":[{"clientDuration":0,"clientTimestamp":1732111856833,"identifier":"ae84faf0-7cd5-4870-a860-5698c8508b7c","messageText":"Melding fra bruker.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111856855},{"clientDuration":0,"clientTimestamp":1732111834877,"identifier":"adcf753e-bb2b-4a00-a6c6-7ebcf683df2c","messageText":"Melding fra veileder.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"agent","role":"Agent","subject":"0052o000009d7J9"},"serverReceivedTimestamp":1732111834344},{"clientDuration":0,"clientTimestamp":1732111810498,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Velkommen til chat med NAV.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"System","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810607},{"clientDuration":0,"clientTimestamp":1732111810498,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Chatbotmelding.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810607},{"clientDuration":0,"clientTimestamp":1732111810498,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Tidligere melding fra veileder.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"Agent","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810607},{"clientDuration":0,"clientTimestamp":1732111810498,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Tidligere melding fra bruker.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810337},{"clientDuration":0,"clientTimestamp":1732111810498,"identifier":"f895ea81-4e7a-4630-94d5-3de815cdaa95","messageText":"Tidligere chatbotmelding.","relatedRecords":["' +
            messagingSessionId +
            '"],"sender":{"appType":"iamessage","role":"EndUser","subject":"v2/iamessage/UNAUTH/NA/uid:66823427-6991-4b41-b932-605b3ad2dd7c"},"serverReceivedTimestamp":1732111810339}]}';

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
