public without sharing class ChatAuthControllerExperience {
    /**
     * @description: Sets the CRM_Authentication_Status__c when the authentication process is initiated
     * @author Stian Ruud Schikora | 09-04-2020
     * @param messagingId [STRING]
     **/
    @AuraEnabled
    public static void setStatusCompleted(Id messagingId) {
        setStatus(messagingId, 'Completed');
    }

    @AuraEnabled
    public static void setStatus(Id messagingId, String status) {
        List<SObject> recordsToUpdate = new List<SObject>();

        try {
            MessagingSession ms = getMessagingSession(messagingId);
            ms.CRM_Authentication_Status__c = status;
            recordsToUpdate.add(ms);

            if (status == 'Completed' && String.isBlank(ms.MessagingEndUser.AccountId)) {
                handleChatAuthentication(ms);
            }
            update recordsToUpdate;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getTypeName() + ' : ' + 'Failed to update authentication status');
        }
    }

    /**
     * @description: Performs necesary steps to related the chat and case to the authenticated individual
     * @author Stian Ruud Schikora | 01-31-2022
     * @param chatTrans
     **/
    private static void handleChatAuthentication(MessagingSession messSess) {
        Id accountId = getPersonAccountId();
        Id contactId = getPersonContactId();
        MessagingEndUser endUser = new MessagingEndUser(Id = messSess.MessagingEndUserId);
        endUser.AccountId = accountId;
        endUser.ContactId = contactId;
        messSess.NKS_Authentication_Timestamp__c = DateTime.now();
        createChatThread(messSess, endUser);

        update endUser;
        if (String.isNotBlank(accountId)) {
            Account personAcc = getPersonAccount(accountId);
            if (
                !personAcc.CRM_Person__r.INT_Confidential__c.equalsIgnoreCase('UGRADERT') ||
                personAcc.CRM_Person__r.INT_IsNavEmployee__c
            )
                //Persons tagged as confidential or is NAV employees cannot be journaled - NKS-430
                messSess.NKS_Journal_Entry_Status__c = 'Completed';
            // System.debug('Goated');
        }
    }

    /**
     * @description: Created the thread equivalent of an authenticated chat
     * @author Stian Ruud Schikora | 01-31-2022
     * @param chatTrans
     * @return Id
     **/
    private static void createChatThread(MessagingSession messSess, MessagingEndUser endUser) {
        Thread__c chatThread = new Thread__c(
            CRM_Thread_Type__c = 'CHAT',
            CRM_Account__c = endUser.AccountId,
            CRM_Contact__c = endUser.ContactId,
            CRM_isActive__c = true,
            CRM_Related_Object__c = messSess.Id,
            CRM_Theme_Group__c = messSess.NKS_Theme_Group__c
        );
        insert chatThread;
    }
    private static MessagingSession getMessagingSession(Id messagingId) {
        return [
            SELECT Id, MessagingEndUser.AccountId, NKS_Theme_Group__c
            FROM MessagingSession
            WHERE Id = :messagingId
        ];
    }

    /**
     * @description: Returns the community url used for chat authentication
     * @author Stian Ruud Schikora | 10-01-2020
     * @return string
     **/
    @AuraEnabled
    public static string getCommunityAuthUrl() {
        List<Network> community = [SELECT Id, Name, UrlPathPrefix FROM Network WHERE Name = 'nks'];
        String communityUrl = community.isEmpty() ? '' : Network.getLoginUrl(community[0].Id);
        communityUrl = communityUrl.removeEnd(communityUrl.substringAfterLast('/'));
        communityUrl += 's/identity-verified?ctid=';

        return communityUrl;
    }

    private static Id getPersonAccountId() {
        return [
            SELECT AccountId
            FROM User
            WHERE
                IsPortalEnabled = TRUE
                AND Id = :UserInfo.getUserId()
                AND AccountId != NULL
                AND Account.IsPersonAccount = TRUE
        ]
        ?.AccountId;
    }

    private static Account getPersonAccount(String accountId) {
        return [
            SELECT Id, CRM_Person__c, CRM_Person__r.INT_Confidential__c, CRM_Person__r.INT_IsNavEmployee__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
    }

    private static Id getPersonContactId() {
        return [
            SELECT ContactId
            FROM User
            WHERE
                IsPortalEnabled = TRUE
                AND Id = :UserInfo.getUserId()
                AND ContactId != NULL
                AND Account.IsPersonAccount = TRUE
        ]
        ?.ContactId;
    }
}
