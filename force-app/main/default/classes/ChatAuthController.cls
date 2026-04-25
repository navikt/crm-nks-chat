public without sharing class ChatAuthController {
    @AuraEnabled
    public static void setStatusRequested(Id messagingId) {
        ChatAuthControllerExperience.setStatus(messagingId, 'Authentication Requested');
    }

    @AuraEnabled(Cacheable=true)
    public static Map<String, String> getMessagingInfo(String messagingId) {
        Map<String, String> messagingInfo;
        try {
            MessagingSession session = [
                SELECT Id, CRM_Authentication_Status__c, EndTime, Status, CRM_Language__c
                FROM MessagingSession
                WHERE Id = :messagingId
            ];

            messagingInfo = new Map<String, String>{
                'AUTH_STATUS' => session.CRM_Authentication_Status__c,
                'END_TIME' => string.valueOf(session.EndTime),
                'CONVERSATION_STATUS' => session.Status,
                'CHAT_LANGUAGE' => session.CRM_Language__c
            };

            return messagingInfo;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getTypeName() + ' : ' + 'Could not retrieve authentication status');
        }
    }

    @AuraEnabled
    public static string getCounselorName(String recordId) {
        Id ownerId = [SELECT OwnerId FROM MessagingSession WHERE Id = :recordId LIMIT 1]?.OwnerId;
        String fullname = [SELECT NKS_FullName__c FROM User WHERE Id = :ownerId LIMIT 1]?.NKS_FullName__c;
        return fullname;
    }
}
