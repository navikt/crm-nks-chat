public class NKS_ConversationEntryController {
    private static LoggerUtility logger = new LoggerUtility('Messaging');
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
                    'Failed to get conversation entries. Status Code: ' + response.getStatusCode(),
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

        Thread__c thread = getThreadDetails(wrapper.conversationEntries[0].relatedRecords[0]);

        List<ConversationEntry> chatbotMessages = new List<ConversationEntry>();
        List<ConversationEntry> userMessages = new List<ConversationEntry>();
        splitChatbotMessagesFromConversation(wrapper.conversationEntries, chatbotMessages, userMessages);

        if (!chatbotMessages.isEmpty()) {
            String formattedChatbotMessages = formatChatbotMessagesAsString(chatbotMessages);
            storeChatbotConversationOnThread(thread.Id, formattedChatbotMessages);
        }

        List<Message__c> messagesToInsert = new List<Message__c>();
        messagesToInsert.add(createAuthEventMessage(session, thread));

        for (ConversationEntry entry : userMessages) {
            if (entry.messageText != null) {
                messagesToInsert.add(createMessage(entry, session, thread));
            }
        }

        if (!messagesToInsert.isEmpty()) {
            insertMessagesAndUpdatedThreadCloseDate(messagesToInsert, thread.Id);
        }
    }

    private static Message__c createAuthEventMessage(MessagingSession msgSession, Thread__c thread) {
        String authText = msgSession.EndUserLanguage == 'en_US'
            ? 'Started authenticated chat'
            : 'Startet innlogget chat';
        return new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Type__c = 'Event',
            CRM_Sent_date__c = msgSession.NKS_Authentication_Timestamp__c,
            CRM_Read__c = false,
            CRM_Message_Text__c = authText
        );
    }

    private static Message__c createMessage(ConversationEntry entry, MessagingSession session, Thread__c thread) {
        Message__c message = new Message__c();
        message.CRM_Thread__c = thread.Id;
        message.CRM_Message_Text__c = entry.messageText;
        message.CRM_Sent_Date__c = DateTime.newInstance(entry.serverReceivedTimestamp);
        message.CRM_Read__c = false;
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

    private static void insertMessagesAndUpdatedThreadCloseDate(List<Message__c> messages, String threadId) {
        try {
            insert messages;
            updateThreadCloseDate(threadId, System.now());
        } catch (Exception e) {
            logger.error('Error saving messages: ' + e.getMessage(), null, CRM_ApplicationDomain.Domain.NKS);
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

            if (isWelcomeMessage(entry)) {
                automaticGreetingFound = true;
                entry.sender.role = 'Agent'; // Welcome message is incorrectly set as User message
                userMessages.add(entry); // Add welcome message to user messages
                continue;
            }

            if (automaticGreetingFound) {
                userMessages.add(entry);
            } else {
                chatbotMessages.add(entry);
            }
        }
    }

    // TODO: Only check sender.role == System to avoid this failing if we change the welcome message in the future?
    private static Boolean isWelcomeMessage(ConversationEntry entry) {
        return entry.messageText != null &&
            'System'.equalsIgnoreCase(entry.sender.role) &&
            (entry.messageText.containsIgnoreCase('Welcome to chat with NAV') ||
            entry.messageText.containsIgnoreCase('Velkommen til chat med NAV'));
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

    private static void storeChatbotConversationOnThread(String threadId, String chatbotConversation) {
        update new Thread__c(Id = threadId, Additional_Information__c = chatbotConversation);
    }

    private static Map<String, User> getNavUserInfoByUserId() {
        Map<String, User> navUserInfoByUserId = new Map<String, User>();
        for (User usr : [
            SELECT Id, Department
            FROM User
            WHERE
                Id IN (
                    SELECT AssigneeId
                    FROM PermissionSetAssignment
                    WHERE PermissionSetGroup.DeveloperName = 'Kontaktsenter'
                )
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
            SELECT Id
            FROM Thread__c
            WHERE CRM_Related_Object__c = :messagingSessionId
            FOR UPDATE
        ];
    }

    @future
    private static void updateThreadClosedate(String threadId, Datetime closeDate) {
        update new Thread__c(Id = threadId, CRM_isActive__c = false, CRM_Closed_Date__c = closeDate);
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
