@isTest
public with sharing class Chat_SurveyHelperTest {
    @isTest
    static void testGetSurveyLink() {
        Case enCase = new Case(Status = 'New');
        MessagingSession transcript = new MessagingSession(
            ChatKey = 'testKey',
            CaseId = enCase.Id,
            CRM_Authentication_Status__c = 'Completed',
            NKS_Authentication_Timestamp__c = Datetime.now()
        );
        String surveyInvitationLink = '';

        Test.startTest();
        try {
            surveyInvitationLink = Chat_SurveyHelper.getSurveyInvitationLink('testKey');
        } catch (Exception e) {
            System.assertEquals(e.getTypeName(), 'QueryException');
        }
        Test.stopTest();
        System.assertEquals(null, surveyInvitationLink);
    }
}
