public without sharing class Chat_SurveyHelper {
    @TestVisible
    private static Boolean testForceException = false;
    @TestVisible
    private static Boolean testHasInvitation = false;
    @TestVisible
    private static String testInvitationLinkValue;

    @AuraEnabled(cacheable=true)
    public static String getSurveyInvitationLink(String sessionKey) {
        if (String.isBlank(sessionKey)) {
            throw new ChatSurveyException('sessionKey is required.');
        }

        try {
            return resolveSurveyInvitationLink(sessionKey);
        } catch (Exception e) {
            throw new ChatSurveyException(
                'An error has occurred while getting SurveyInvitation link. ' +
                    'sessionKey=' +
                    sessionKey +
                    ', message=' +
                    e.getMessage()
            );
        }
    }

    private static String resolveSurveyInvitationLink(String sessionKey) {
        if (Test.isRunningTest() && testForceException) {
            throw new ChatSurveyException('forced test exception');
        }

        if (Test.isRunningTest() && testHasInvitation) {
            return testInvitationLinkValue;
        }

        List<SurveyInvitation> invitations = [
            SELECT InvitationLink
            FROM SurveyInvitation
            WHERE
                MessagingSession__c IN (
                    SELECT Id
                    FROM MessagingSession
                    WHERE SessionKey = :sessionKey
                )
            LIMIT 1
        ];

        if (invitations.isEmpty()) {
            return '';
        }

        return invitations[0].InvitationLink;
    }

    private class ChatSurveyException extends Exception {
    }
}
