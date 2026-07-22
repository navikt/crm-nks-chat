public without sharing class Chat_SurveyHelper {
    /**
     * @description Function to get InvitationLink for a Chat session
     * @param String sessionKey
     * @return String surveyInvitationLink
     */
    @AuraEnabled(cacheable=true)
    public static String getSurveyInvitationLink(String sessionKey) {
        if (String.isBlank(sessionKey)) {
            throw new ChatSurveyException('sessionKey is required.');
        }

        String surveyInvitationLink = '';
        try {
            surveyInvitationLink = [
                SELECT InvitationLink
                FROM SurveyInvitation
                WHERE MessagingSession__c IN (SELECT Id
                FROM MessagingSession
                WHERE SessionKey = :sessionKey)
                LIMIT 1
            ]?.InvitationLink;
        } catch (QueryException e) {
            return '';
        } catch (Exception e) {
            throw new ChatSurveyException(
                'An error has occurred while getting SurveyInvitation link. ' +
                    'sessionKey=' +
                    sessionKey +
                    ', message=' +
                    e.getMessage()
            );
        }
        return surveyInvitationLink;
    }

    private class ChatSurveyException extends Exception {
    }
}
