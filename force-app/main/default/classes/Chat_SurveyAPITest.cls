@isTest
public with sharing class Chat_SurveyAPITest {
    @IsTest
    static void testGetSurveyInvitationLink() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = System.Url.getOrgDomainUrl() + '/services/apexrest/MessagingSession/';
        request.httpMethod = 'GET';
        request.addParameter('ChatKey', '12345');
        request.addHeader('X-Correlation-ID', 'test123');
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        Chat_SurveyAPI.getSurveyInvitationLink();
        Test.stopTest();

        System.assertEquals(200, response.statusCode);
        System.assert(response.responseBody != null);
    }

    @IsTest
    static void testGetSurveyInvitationLinkException() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = System.Url.getOrgDomainUrl() + '/services/apexrest/MessagingSession/';
        request.httpMethod = 'GET';
        request.addParameter('ChatKey', 'test');
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        Chat_SurveyAPI.getSurveyInvitationLink();
        Test.stopTest();

        System.assertEquals(500, response.statusCode);
        System.assert(response.responseBody != null);
    }
}
