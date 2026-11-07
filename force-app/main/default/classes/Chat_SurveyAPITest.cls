@isTest
public with sharing class Chat_SurveyAPITest {
    @TestSetup
    static void makeData() {
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        System.runAs(thisUser) {
            MessagingChannel channel = (MessagingChannel) UTIL_TestDataFactory.createRecord(new MessagingChannel());
            MessagingEndUser endUser = (MessagingEndUser) UTIL_TestDataFactory.createRecord(
                new MessagingEndUser(MessagingChannelId = channel.Id)
            );
            UTIL_TestDataFactory.createRecord(
                new MessagingSession(
                    MessagingChannelId = channel.Id,
                    MessagingEndUserId = endUser.Id,
                    SessionKey = '12345'
                )
            );
        }
    }

    @IsTest
    static void testGetSurveyInvitationLink() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = System.Url.getOrgDomainUrl() + '/services/apexrest/MessagingSession/';
        request.httpMethod = 'GET';
        request.addParameter('SessionKey', '12345');
        request.addHeader('X-Correlation-ID', 'test123');
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        Chat_SurveyAPI.getSurveyInvitationLink();
        Test.stopTest();

        Assert.areEqual(200, response.statusCode);
        Assert.isNotNull(response.responseBody, 'Expected responseBody to be not null');
    }

    @IsTest
    static void testGetSurveyInvitationLinkException() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = System.Url.getOrgDomainUrl() + '/services/apexrest/MessagingSession/';
        request.httpMethod = 'GET';
        request.addParameter('SessionKey', 'test');
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        Chat_SurveyAPI.getSurveyInvitationLink();
        Test.stopTest();

        Assert.areEqual(500, response.statusCode, 'Expected status code to be 500');
        Assert.isNotNull(response.responseBody, 'Expected responseBody to be not null');
    }
}
