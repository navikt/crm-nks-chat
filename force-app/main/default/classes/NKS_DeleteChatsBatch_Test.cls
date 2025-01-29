@isTest
public class NKS_DeleteChatsBatch_Test {
    @testSetup
    static void setupTestData() {
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

            // TODO: Not possible to insert Conversation, and it is required to insert Conversation Entry...
            /*ConversationEntry entry = new ConversationEntry();
            entry.ConversationId = '0dwKD0000005IwSYAU';
            entry.Seq = 0;
            entry.EntryTime = Datetime.now();
            entry.EntryType = 'Text';
            entry.ActorType = 'EndUser';
            insert entry;*/
        }
    }

    /*@isTest
    static void testBatchExecution() {
        Test.startTest();
        NKS_DeleteChatsBatch batch = new NKS_DeleteChatsBatch();
        Database.executeBatch(batch);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ConversationEntry]);
    }*/

    @isTest
    static void testSchedulerExecution() {
        Test.startTest();
        String cron = '0 0 * * * ?';
        String jobId = System.schedule('Test Delete Chats Batch', cron, new NKS_DeleteChatsBatch());
        Test.stopTest();

        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered FROM CronTrigger WHERE id = :jobId];
        Assert.areEqual(cron, ct.CronExpression, 'Cron expression should match the one used in scheduling');
        Assert.areEqual(0, ct.TimesTriggered, 'Job should not have triggered yet in test context');
    }
}
