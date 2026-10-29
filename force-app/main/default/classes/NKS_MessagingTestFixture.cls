@IsTest
public class NKS_MessagingTestFixture {
    public static MessagingSession createSession(String status, Boolean withThread) {
        MessagingSession session;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String channelName = 'TestChannel' + UTIL_TestDataFactory.generateRandomString(8);
            MessagingChannel channel = (MessagingChannel) UTIL_TestDataFactory.createRecord(
                new MessagingChannel(DeveloperName = channelName, MessagingPlatformKey = channelName)
            );
            MessagingEndUser endUser = (MessagingEndUser) UTIL_TestDataFactory.createRecord(
                new MessagingEndUser(MessagingChannelId = channel.Id, MessageType = 'Text')
            );
            MessagingSession record = new Set<String>{ 'Ended', 'Inactive', 'Error' }.contains(status)
                ? new MessagingSession(
                      MessagingChannelId = channel.Id,
                      MessagingEndUserId = endUser.Id,
                      Status = status,
                      EndTime = Datetime.now().addMinutes(-5)
                  )
                : new MessagingSession(
                      MessagingChannelId = channel.Id,
                      MessagingEndUserId = endUser.Id,
                      Status = status
                  );
            session = (MessagingSession) UTIL_TestDataFactory.createRecord(record);
            if (withThread) {
                insert new Thread__c(CRM_Related_Object__c = session.Id);
            }
        }
        return session;
    }

    public static MessagingSession hydratedSession(Id sessionId, String identifier) {
        MessagingSession stored = [SELECT EndUserContactId FROM MessagingSession WHERE Id = :sessionId];
        return (MessagingSession) JSON.deserialize(
            JSON.serialize(
                new Map<String, Object>{
                    'Id' => sessionId,
                    'EndUserContactId' => stored.EndUserContactId,
                    'CRM_Authentication_Status__c' => 'Completed',
                    'Conversation' => new Map<String, Object>{ 'ConversationIdentifier' => identifier },
                    'EndUserLanguage' => 'en_US'
                }
            ),
            MessagingSession.class
        );
    }

    public static void assertLogged(String text) {
        Test.getEventBus().deliver();
        List<Application_Log__c> logs = [
            SELECT Log_level__c, Log_message__c
            FROM Application_Log__c
        ];
        for (Application_Log__c log : logs) {
            if (log.Log_message__c != null && log.Log_message__c.contains(text)) {
                Assert.areNotEqual('Info', log.Log_level__c);
                return;
            }
        }
        Assert.fail('Expected failure log containing: ' + text);
    }
}
