@RestResource(urlMapping='/MessagingSession/')
global with sharing class Chat_SurveyAPI {
    private static LoggerUtility logger = new LoggerUtility('Chat API');
    /**
     * @description Function to get SurveyInvitationLink via REST API
     * @author Sara Mohammadi | 01.06.2023
     */
    @HttpGet
    global static void getSurveyInvitationLink() {
        String chatKey = RestContext.request.params.get('ChatKey');
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;
        response.addHeader('Content-Type', 'application/json');

        /**
         * Gets the X-Correlation header for an incoming request
         * CorrelationI (Transit ID): unique identifier value for requests and messages using as reference to a particular transaction
         */
        String correlationId = request.headers.containsKey('X-Correlation-ID')
            ? request.headers.get('X-Correlation-ID')
            : null;
        logger.apiTransaction(correlationId, RestContext.request, CRM_ApplicationDomain.Domain.NKS);

        try {
            String surveyInvitationLink = Chat_SurveyHelper.getSurveyInvitationLink(chatKey);
            response.statusCode = 200;
            response.responseBody = Blob.valueOf(JSON.serializePretty(surveyInvitationLink));
            if (Test.isRunningTest() && chatKey == 'test') {
                throw new CalloutException('This is a test exception!');
            }
        } catch (Exception ex) {
            response.statusCode = 500;
            response.responseBody = Blob.valueOf(JSON.serialize(ex.getMessage()));
            logger.error(ex.getMessage(), null, CRM_ApplicationDomain.Domain.NKS, correlationId);
        } finally {
            logger.publish();
        }
    }
}
