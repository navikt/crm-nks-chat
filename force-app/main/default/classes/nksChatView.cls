public with sharing class nksChatView {
    @AuraEnabled(cacheable=true)
    public static Thread__c getThread(String chatId) {
        List<Thread__c> thread = [
            SELECT Id, CRM_Theme_Group_Name__c
            FROM Thread__c
            WHERE CRM_Related_Object__c = :chatId
            LIMIT 1
        ];
        if (thread.size() > 0) {
            return thread[0];
        }
        return null;
    }

    @AuraEnabled(cacheable=true)
    public static String getChatbotMessage(Id chatId, Id userId) {
        List<User> user = [SELECT accountId FROM User WHERE id = :userId LIMIT 1];
        if (user.size() == 0) {
            return 'Det oppstod en feil';
        }
        return nksFridaLog.getChatbotMessage(chatId, user[0].accountId);
    }
}
