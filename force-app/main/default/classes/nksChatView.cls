public with sharing class nksChatView {
    @AuraEnabled(cacheable=true)
    public static Id getThreadId(String chatId) {
        List<Thread__c> thread = [SELECT Id FROM Thread__c WHERE CRM_Related_Object__c = :chatId LIMIT 1];
        if (thread.size() > 0) {
            return thread[0].Id;
        }
        return null;
    }

    @AuraEnabled(cacheable=true)
    public static String getChatbotMessage(Id chatId, Id userId, Boolean isChatTranscript) {
        List<User> user = [SELECT accountId FROM User WHERE id = :userId LIMIT 1];
        if (user.size() == 0) {
            return 'Det oppstod en feil';
        }
        return nksFridaLog.getChatbotMessage(chatId, user[0].accountId, isChatTranscript);
    }

    @AuraEnabled(cacheable=true)
    public static String getObjectInfo(Id recordId) {
        try {
            return recordId.getSObjectType().getDescribe().getName();
        } catch (Exception e) {
            throw new AuraHandledException('Unable to determine object type: ' + e.getMessage());
        }
    }
}
