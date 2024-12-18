public without sharing class nksFridaLog {
    public static String getChatbotMessage(Id chatId, Id accountId, Boolean isChatTranscript) {
        if (isChatTranscript) {
            List<Case> caseRef = [
                SELECT Description
                FROM Case
                WHERE SourceId = :chatId AND accountId = :accountId
                LIMIT 1
            ];
            if (caseRef.size() == 0) {
                return 'Det oppstod en feil';
            }
            return NKS_CaseBotConversationHandler.formatBotConversation(caseRef[0].Description);
        } else {
            List<Thread__c> threadRef = [
                SELECT CRM_Additional_Information__c
                FROM Thread__c
                WHERE CRM_Related_Object__c = :chatId AND CRM_Account__c = :accountId
                LIMIT 1
            ];
            if (threadRef.size() == 0) {
                return 'Det oppstod en feil';
            }
            return threadRef[0].CRM_Additional_Information__c;
        }
    }
}
