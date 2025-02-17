public without sharing class Chat_SurveyHelper {
    /**
     * @description Function to get InvitationLink for a Case related to Chat
     * @param String chatKey
     * @return String surveyInvitationLink
     */
    @AuraEnabled(cacheable=true)
    public static String getSurveyInvitationLink(String chatKey) {
        String surveyInvitationLink = '';
        try {
            surveyInvitationLink = [
                SELECT InvitationLink
                FROM SurveyInvitation
                WHERE Case__c IN (SELECT CaseId FROM MessagingSession WHERE ChatKey = :chatKey)
                LIMIT 1
            ]
            ?.InvitationLink;
        } catch (QueryException e) {
            System.debug('An error has occurred on getting MessagingSession or SurveyInvitation: ' + e.getMessage());
        }
        return surveyInvitationLink;
    }
}
