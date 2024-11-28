public without sharing class nksFridaLog {
    public static String getChatbotMessage(Id chatId, Id accountId) {
        Schema.SObjectType sObjectType = chatId.getSObjectType();
        if (sObjectType == Case.SObjectType) {
            List<Case> caseRef = [SELECT Description FROM Case WHERE SourceId = :chatId AND AccountId = :accountId LIMIT 1];
            if (caseRef.size() == 0) {
                return 'Det oppstod en feil';
            }
            return NKS_CaseBotConversationHandler.formatBotConversation(caseRef[0].Description);
        } else if (sObjectType == Thread__c.SObjectType) {
            List<Thread__c> threadRef = [SELECT Additional_Information__c FROM Thread__c WHERE CRM_Related_Object__c = :chatId AND CRM_Account__c = :accountId LIMIT 1];
            if (threadRef.size() == 0) {
                return 'Det oppstod en feil';
            }
            return NKS_CaseBotConversationHandler.formatBotConversation(threadRef[0].Additional_Information__c);
        } else { 
            return 'Det oppstod en feil';
        }
    }
}
