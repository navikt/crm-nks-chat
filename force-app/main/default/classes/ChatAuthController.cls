public without sharing class ChatAuthController {
    @AuraEnabled
    public static void setStatus(Id chatTranscriptId, String status) {
        List<SObject> recordsToUpdate = new List<SObject>();

        try {
            MessagingSession messagingSession = getMessagingSession(messagingSessionId);
            messagingSession.CRM_Authentication_Status__c = status;
            recordsToUpdate.add(messagingSession);

            if (status == 'Completed' && String.isBlank(messagingSession.AccountId)) {
                handleChatAuthentication(messagingSession);

                if (String.isNotBlank(messagingSession.CaseId)) {
                    Case case = new Case(Id = messagingSession.CaseId, AccountId = messagingSession.accountId, ContactId = messagingSession.contactId);
                    recordsToUpdate.add(case);
                }
            }
            update recordsToUpdate;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getTypeName() + ' : ' + 'Failed to update authentication status');
        }
    }

    private static void handleChatAuthentication(MessagingSession messagingSession) {
        Id accountId = getPersonAccountId();
        Id contactId = getPersonContactId();
        MessagingSession.AccountId = accountId;
        MessagingSession.ContactId = contactId;
        MessagingSession.NKS_Authentication_Timestamp__c = DateTime.now();
        createChatThread(chatTrans);

        if (String.isNotBlank(accountId)) {
            Account personAcc = getPersonAccount(accountId);
            if (
                !personAcc.CRM_Person__r.INT_Confidential__c.equalsIgnoreCase('UGRADERT') ||
                personAcc.CRM_Person__r.INT_IsNavEmployee__c
            )
                //Persons tagged as confidential or is NAV employees cannot be journaled - NKS-430
                messagingSession.NKS_Journal_Entry_Status__c = 'Completed';
        }
    }

    private static void createChatThread(MessagingSession messagingSession) {
        Thread__c messagingThread = new Thread__c(
            CRM_Thread_Type__c = 'CHAT',
            CRM_Account__c = messagingSession.AccountId,
            CRM_Contact__c = messagingSession.ContactId,
            CRM_isActive__c = true,
            CRM_Related_Object__c = messagingSession.Id,
            CRM_Theme_Group__c = messagingSession.NKS_Theme_Group__c
        );
        insert messagingSession;
    }

    private static MessagingSession getMessagingSession(Id messagingSessionId) {
        return [SELECT Id, CaseId, AccountId, NKS_Theme_Group__c FROM MessagingSession WHERE Id = :messagingSessionId];
    }

    @AuraEnabled
    public static string getCommunityAuthUrl() {
        List<Network> community = [SELECT Id FROM Network WHERE Name = 'nks'];
        String communityUrl = community.isEmpty() ? '' : Network.getLoginUrl(community[0].Id);
        communityUrl = communityUrl.removeEnd(communityUrl.substringAfterLast('/'));
        communityUrl += 's/identity-verified?ctid=';

        return communityUrl;
    }


    //@description: Returns the CRM_Authentication_Status__c, and status of the messaging Session

    @AuraEnabled(Cacheable=true)
    public static Map<String, String> getChatInfo(String messagingSessionId) {
        Map<String, String> chatInfo;
        try {
            MessagingSession messagingSession = [
                SELECT
                    Id,
                    CRM_Authentication_Status__c,
                    AccountId,
                    Account.CRM_Person__c,
                    Account.CRM_Person__r.INT_Confidential__c,
                    Account.CRM_Person__r.INT_IsNavEmployee__c,
                    Account.CRM_Person__r.NKS_NumberOfSecurityMeasures__c,
                    CaseId,
                    LiveChatButton.WindowLanguage,
                    Status,
                    EndTime
                FROM messagingSession
                WHERE Id = :messagingSessionId
            ];
            chatInfo = new Map<String, String>{
                'AUTH_STATUS' => messagingSession.CRM_Authentication_Status__c,
                'CONVERSATION_STATUS' => messagingSession.Status,
                'ACCOUNTID' => messagingSession.accountId,
                'CASEID' => messagingSession.CaseId,
                'PERSONID' => messagingSession.Account.CRM_Person__c,
                'IS_NAV_EMPLOYEE' => isNavEmployee(messagingSession),
                'IS_CONFIDENTIAL' => '' + personIsConfidential(messagingSession),
                'NMB_SECURITY_MEASURES' => numberOfSecurityMeasures(messagingSession),
                'CHAT_LANGUAGE' => String.isNotBlank(messagingSession.LiveChatButton.WindowLanguage) //what is this? -Jan Robert
                    ? trans.LiveChatButton.WindowLanguage
                    : 'no',
                'END_TIME' => string.valueOf(messagingSession.EndTime)
            };
            return chatInfo;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getTypeName() + ' : ' + 'Could not retrieve authentication status');
        }
    }

    private static String personIsConfidential(MessagingSession messagingSession) {
        if (String.isNotBlank(messagingSession.AccountId)) {
            return messagingSession.Account.CRM_Person__r.INT_Confidential__c.equalsIgnoreCase('UGRADERT') ? 'false' : 'true';
        }
        return 'false';
    }

    private static String isNavEmployee(MessagingSession messagingSession) {
        if (String.isNotBlank(messagingSession.AccountId)) {
            return messagingSession.Account.CRM_Person__r.INT_IsNavEmployee__c ? 'true' : 'false';
        }
        return 'false';
    }

    private static String numberOfSecurityMeasures(MessagingSession messagingSession) {
        if (String.isNotBlank(messagingSession.AccountId)) {
            return '' + messagingSession.Account.CRM_Person__r.NKS_NumberOfSecurityMeasures__c;
        }

        return '0';
    }

    /**
     * @description: Sets the CRM_Authentication_Status__c when the authentication process is initiated
     * @author Stian Ruud Schikora | 09-04-2020
     * @param chatTranscriptId [STRING]
     **/
    @AuraEnabled
    public static void setStatusRequested(Id messagingSessionId) {
        setStatus(messagingSessionId, 'Authentication Requested');
    }

    @AuraEnabled
    public static void setStatusCompleted(Id messagingSessionId) {
        setStatus(messagingSessionId, 'Completed');
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

    @AuraEnabled
    public static string getCounselorName(String recordId) {
        Id ownerId = [SELECT OwnerId FROM messagingSession WHERE Id = :recordId LIMIT 1]?.OwnerId;
        String fullname = [SELECT NKS_FullName__c FROM User WHERE Id = :ownerId LIMIT 1]?.NKS_FullName__c;
        return fullname;
    }
}
