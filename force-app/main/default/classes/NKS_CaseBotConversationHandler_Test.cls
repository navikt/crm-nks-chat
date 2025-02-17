@isTest
public class NKS_CaseBotConversationHandler_Test {
    @TestSetup
    static void makeData() {
        String botConversation = '22:15:14 - bot:\n';
        botConversation += 'Det er mange som vil snakke med oss nå. Hold chatten åpen og følg med, så svarer vi deg så snart vi kan.\n';
        botConversation += '22:15:14 - bot:\n';
        botConversation = 'Jeg setter deg over, et øyeblikk.\n';

        Case botCase = (Case) UTIL_TestDataFactory.createRecord(new Case(Description = botConversation));
    }

    //Test må tilpasses MessagingSession
    @isTest
    static void testConversationFormat() {
        Case case = [SELECT Id FROM Case LIMIT 1];
        MessagingSession session = (MessagingSession) UTIL_TestDataFactory.createRecord(
            new MessagingSession(CaseId = case.Id)
        );

        Test.startTest();
        case.SourceId = session.Id;
        update case;
        Test.stopTest();

        System.assertNotEquals(null, [SELECT Id, NKS_Conversation__c FROM Case LIMIT 1]?.NKS_Conversation__c);
    }
}
