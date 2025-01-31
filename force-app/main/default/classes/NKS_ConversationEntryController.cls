public class NKS_ConversationEntryController {
    private static LoggerUtility logger = new LoggerUtility('Messaging');
    // Welcome message text from the Messaging Component in Messaging Settings
    private static final String welcomeMessageSubstringNO = 'Velkommen til chat med NAV';
    private static final String welcomeMessageSubstringEN = 'Welcome to chat with NAV';
    private static Map<String, User> navUserInfoByUserId = getNavUserInfoByUserId();

    public static void convertConversationEntries(
        List<MessagingSession> msgSessions,
        Long startTimestamp,
        Long endTimestamp,
        String queryDirection,
        Integer recordLimit
    ) {
        if (msgSessions.isEmpty()) {
            return;
        }

        List<Id> messagingSessionIds = new List<Id>();
        for (MessagingSession msgSession : msgSessions) {
            messagingSessionIds.add(msgSession.Id);
        }
        List<MessagingSession> messagingSessions = [
            SELECT
                Id,
                Conversation.ConversationIdentifier,
                Endtime,
                Status,
                EndUserAccountId,
                EndUserContactId,
                EndUserLanguage,
                NKS_Authentication_Timestamp__c
            FROM MessagingSession
            WHERE Id IN :messagingSessionIds
        ];

        for (MessagingSession session : messagingSessions) {
            String conversationIdentifier = Test.isRunningTest()
                ? '17978db9-ed91-4363-adcb-d1b581168eed'
                : session.Conversation.ConversationIdentifier;
            if (conversationIdentifier == null) {
                continue;
            }

            processConversationEntry(
                session,
                conversationIdentifier,
                startTimestamp,
                endTimestamp,
                queryDirection,
                recordLimit
            );
        }
    }

    private static void processConversationEntry(
        MessagingSession session,
        String conversationIdentifier,
        Long startTimestamp,
        Long endTimestamp,
        String queryDirection,
        Integer recordLimit
    ) {
        try {
            HttpResponse response = NKS_ConversationEntryService.getConversationEntryMessages(
                conversationIdentifier,
                startTimestamp,
                endTimestamp,
                queryDirection,
                recordLimit
            );

            if (response.getStatusCode() == 200) {
                ConversationEntryWrapper wrapper = (ConversationEntryWrapper) JSON.deserialize(
                    response.getBody(),
                    ConversationEntryWrapper.class
                );
                createThreadMessages(wrapper, session);
            } else {
                logger.httpError(
                    'Failed to get conversation entries for session: ' +
                        session.Id +
                        '.\nStatus Code: ' +
                        response.getStatusCode(),
                    response,
                    null,
                    CRM_ApplicationDomain.Domain.NKS
                );
            }
        } catch (Exception e) {
            logger.exception(e, CRM_ApplicationDomain.Domain.NKS);
        } finally {
            logger.publish();
        }
    }

    private static void createThreadMessages(ConversationEntryWrapper wrapper, MessagingSession session) {
        if (wrapper == null || wrapper.conversationEntries == null || wrapper.conversationEntries.isEmpty()) {
            return;
        }

        Thread__c thread = getThreadDetails(session.Id);
        if (thread == null) {
            return;
        }

        List<ConversationEntry> chatbotMessages = new List<ConversationEntry>();
        List<ConversationEntry> userMessages = new List<ConversationEntry>();
        splitChatbotMessagesFromConversation(wrapper.conversationEntries, chatbotMessages, userMessages);

        if (!chatbotMessages.isEmpty()) {
            thread.CRM_Additional_Information__c = formatChatbotMessagesAsString(chatbotMessages);
        }

        List<Message__c> messagesToInsert = new List<Message__c>{ createAuthEventMessage(session, thread) };

        for (ConversationEntry entry : userMessages) {
            if (entry.messageText != null) {
                messagesToInsert.add(createMessage(entry, session, thread));
            }
        }

        if (!messagesToInsert.isEmpty()) {
            insertMessages(messagesToInsert);
        }
        updateThread(thread);
    }

    private static Message__c createAuthEventMessage(MessagingSession msgSession, Thread__c thread) {
        String authText = msgSession.EndUserLanguage == 'en_US'
            ? 'Started authenticated chat'
            : 'Startet innlogget chat';

        return new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Type__c = 'Event',
            CRM_Sent_date__c = msgSession.NKS_Authentication_Timestamp__c,
            CRM_Read__c = true,
            CRM_Message_Text__c = authText
        );
    }

    private static Message__c createMessage(ConversationEntry entry, MessagingSession session, Thread__c thread) {
        Message__c message = new Message__c();
        message.CRM_Thread__c = thread.Id;
        message.CRM_Message_Text__c = entry.messageText;
        message.CRM_Sent_Date__c = DateTime.newInstance(entry.serverReceivedTimestamp);
        message.CRM_Read__c = true;
        message.CRM_Type__c = 'Message';

        if ('Agent'.equals(entry.sender.role)) {
            User navUser = navUserInfoByUserId.get(entry.sender.subject);
            if (navUser != null) {
                message.CRM_From_User__c = navUser.Id;
                message.CRM_From_NAV_Unit__c = navUser.Department;
            }
        } else {
            message.CRM_From_Contact__c = session.EndUserContactId;
        }

        return message;
    }

    private static void insertMessages(List<Message__c> messages) {
        try {
            insert messages;
        } catch (Exception e) {
            logger.error('Error inserting messages: ' + e.getMessage(), null, CRM_ApplicationDomain.Domain.NKS);
        }
    }

    private static void updateThread(Thread__c thread) {
        try {
            thread.CRM_isActive__c = false;
            thread.CRM_Closed_Date__c = System.now();
            update thread;
        } catch (Exception e) {
            logger.error('Error updating thread: ' + e.getMessage(), null, CRM_ApplicationDomain.Domain.NKS);
        }
    }

    private static void splitChatbotMessagesFromConversation(
        List<ConversationEntry> entries,
        List<ConversationEntry> chatbotMessages,
        List<ConversationEntry> userMessages
    ) {
        Boolean automaticGreetingFound = false;
        for (ConversationEntry entry : entries) {
            if (entry.messageText == null) {
                continue;
            }
            entry.messageText = entry.messageText.unescapeHtml4(); // Connect API returns HTML-encoded strings -> decode for further processing

            if (!automaticGreetingFound && isWelcomeMessage(entry)) {
                automaticGreetingFound = true;
                entry.sender.role = 'Agent'; // Welcome message role is incorrectly set
            }

            if (automaticGreetingFound) {
                userMessages.add(entry);
            } else {
                chatbotMessages.add(entry);
            }
        }
    }

    private static Boolean isWelcomeMessage(ConversationEntry entry) {
        return entry.messageText != null &&
            'System'.equalsIgnoreCase(entry.sender.role) &&
            (entry.messageText.containsIgnoreCase(welcomeMessageSubstringEN) ||
            entry.messageText.containsIgnoreCase(welcomeMessageSubstringNO));
    }

    private static String formatChatbotMessagesAsString(List<ConversationEntry> entries) {
        List<String> formattedMessages = new List<String>();

        for (ConversationEntry entry : entries) {
            String messageText = entry.messageText;
            // Assuming user sent more messages after chat was sent to queue
            if (!messageText.startsWith('Bruker:') && !messageText.startsWith('Frida:')) {
                messageText = 'Bruker: ' + messageText;
            }
            formattedMessages.add(messageText);
        }

        return String.join(formattedMessages, '\n');
    }

    private static Map<String, User> getNavUserInfoByUserId() {
        Map<String, User> navUserInfoByUserId = new Map<String, User>();
        for (User usr : [
            SELECT Id, Department
            FROM User
            WHERE
                ProfileId IN (SELECT Id FROM Profile WHERE Name LIKE 'NAV Kontaktsenter%')
                AND IsActive = TRUE
                AND CRM_NAV_Ident__c != NULL
                AND CRM_NAV_Ident__c != ''
        ]) {
            navUserInfoByUserId.put(usr.Id, usr);
        }

        return navUserInfoByUserId;
    }

    private static Thread__c getThreadDetails(Id messagingSessionId) {
        return [
            SELECT Id, CRM_Additional_Information__c, CRM_isActive__c, CRM_Closed_Date__c
            FROM Thread__c
            WHERE CRM_Related_Object__c = :messagingSessionId
            FOR UPDATE
        ];
    }

    public class ConversationEntryWrapper {
        public List<ConversationEntry> conversationEntries;
    }

    public class ConversationEntry {
        public Integer clientDuration;
        public Long clientTimestamp;
        public String identifier;
        public String messageText;
        public List<String> relatedRecords;
        public Sender sender;
        public Long serverReceivedTimestamp;
    }

    public class Sender {
        public String appType;
        public String role;
        public String subject;
    }
}
