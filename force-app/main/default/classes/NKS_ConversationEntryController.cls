public class NKS_ConversationEntryController {
    private static LoggerUtility logger = new LoggerUtility('Messaging');
    private static final String LOG_PREFIX = 'NKS_ConversationEntryController';

    private static final String PREFIX_FRIDA = 'Frida:';
    private static final String PREFIX_BRUKER = 'Bruker:';
    private static final String PREFIX_VEILEDER = 'Veileder:';

    private static Map<String, User> navUserInfoByUserId = getNavUserInfoByUserId();

    public static void convertConversationEntries(
        List<MessagingSession> msgSessions,
        Long startTimestamp,
        Long endTimestamp,
        String queryDirection,
        Integer recordLimit
    ) {
        logger.info(
            LOG_PREFIX +
                '.convertConversationEntries START' +
                ' | inputSessions=' +
                (msgSessions == null ? null : msgSessions.size()) +
                ' | startTimestamp=' +
                startTimestamp +
                ' | endTimestamp=' +
                endTimestamp +
                ' | queryDirection=' +
                queryDirection +
                ' | recordLimit=' +
                recordLimit +
                ' | runningUserId=' +
                UserInfo.getUserId() +
                ' | runningUserName=' +
                UserInfo.getUserName(),
            null,
            CRM_ApplicationDomain.Domain.NKS
        );

        try {
            if (msgSessions == null || msgSessions.isEmpty()) {
                logger.info(
                    LOG_PREFIX + '.convertConversationEntries EXIT | No messaging sessions provided',
                    null,
                    CRM_ApplicationDomain.Domain.NKS
                );
                return;
            }

            List<Id> messagingSessionIds = new List<Id>();
            for (MessagingSession msgSession : msgSessions) {
                if (msgSession != null && msgSession.Id != null) {
                    messagingSessionIds.add(msgSession.Id);
                }
            }

            if (messagingSessionIds.isEmpty()) {
                logger.info(
                    LOG_PREFIX + '.convertConversationEntries EXIT | No valid messaging session ids',
                    null,
                    CRM_ApplicationDomain.Domain.NKS
                );
                return;
            }

            List<MessagingSession> messagingSessions = [
                SELECT
                    Id,
                    ConversationId,
                    Conversation.ConversationIdentifier,
                    EndTime,
                    Status,
                    EndUserAccountId,
                    EndUserContactId,
                    EndUserLanguage,
                    NKS_Authentication_Timestamp__c,
                    CRM_Authentication_Status__c,
                    CreatedDate
                FROM MessagingSession
                WHERE Id IN :messagingSessionIds
            ];

            logger.info(
                LOG_PREFIX +
                    '.convertConversationEntries | queriedMessagingSessions=' +
                    JSON.serialize(messagingSessions),
                null,
                CRM_ApplicationDomain.Domain.NKS
            );

            for (MessagingSession session : messagingSessions) {
                try {
                    if (session.CRM_Authentication_Status__c != 'Completed') {
                        logger.info(
                            LOG_PREFIX +
                                '.convertConversationEntries | Skipping non-authenticated session' +
                                ' | sessionId=' +
                                session.Id +
                                ' | authStatus=' +
                                session.CRM_Authentication_Status__c,
                            null,
                            CRM_ApplicationDomain.Domain.NKS
                        );
                        continue;
                    }

                    String conversationIdentifier = Test.isRunningTest()
                        ? '17978db9-ed91-4363-adcb-d1b581168eed'
                        : session.Conversation.ConversationIdentifier;

                    if (conversationIdentifier == null) {
                        logger.error(
                            LOG_PREFIX +
                                '.convertConversationEntries | Skipping session because conversationIdentifier is null' +
                                ' | sessionId=' +
                                session.Id,
                            null,
                            CRM_ApplicationDomain.Domain.NKS
                        );
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
                } catch (Exception sessionException) {
                    logger.error(
                        LOG_PREFIX +
                            '.convertConversationEntries | Session processing failed' +
                            ' | sessionId=' +
                            session.Id +
                            ' | message=' +
                            sessionException.getMessage() +
                            ' | stack=' +
                            sessionException.getStackTraceString(),
                        null,
                        CRM_ApplicationDomain.Domain.NKS
                    );
                }
            }
        } catch (Exception e) {
            logger.exception(e, CRM_ApplicationDomain.Domain.NKS);
        } finally {
            logger.info(LOG_PREFIX + '.convertConversationEntries END', null, CRM_ApplicationDomain.Domain.NKS);
            logger.publish();
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
        logger.info(
            LOG_PREFIX +
                '.processConversationEntry START' +
                ' | sessionId=' +
                session.Id +
                ' | conversationIdentifier=' +
                conversationIdentifier,
            null,
            CRM_ApplicationDomain.Domain.NKS
        );

        try {
            HttpResponse response = NKS_ConversationEntryService.getConversationEntryMessages(
                conversationIdentifier,
                startTimestamp,
                endTimestamp,
                queryDirection,
                recordLimit
            );

            logger.info(
                LOG_PREFIX +
                    '.processConversationEntry | HTTP response' +
                    ' | sessionId=' +
                    session.Id +
                    ' | statusCode=' +
                    response.getStatusCode() +
                    ' | body=' +
                    response.getBody(),
                null,
                CRM_ApplicationDomain.Domain.NKS
            );

            if (response.getStatusCode() == 200) {
                ConversationEntryWrapper wrapper = (ConversationEntryWrapper) JSON.deserialize(
                    response.getBody(),
                    ConversationEntryWrapper.class
                );

                logger.info(
                    LOG_PREFIX +
                        '.processConversationEntry | wrapper deserialized' +
                        ' | sessionId=' +
                        session.Id +
                        ' | conversationEntriesSize=' +
                        (wrapper == null ||
                            wrapper.conversationEntries == null
                            ? 0
                            : wrapper.conversationEntries.size()),
                    null,
                    CRM_ApplicationDomain.Domain.NKS
                );

                createThreadMessages(wrapper, session);
            } else {
                logger.httpError(
                    'Failed to get conversation entries for session: ' +
                        session.Id +
                        '.\nStatus Code: ' +
                        response.getStatusCode() +
                        '\nResponse Body: ' +
                        response.getBody(),
                    response,
                    null,
                    CRM_ApplicationDomain.Domain.NKS
                );
            }
        } catch (Exception e) {
            logger.error(
                LOG_PREFIX +
                    '.processConversationEntry ERROR' +
                    ' | sessionId=' +
                    session.Id +
                    ' | message=' +
                    e.getMessage() +
                    ' | stack=' +
                    e.getStackTraceString(),
                null,
                CRM_ApplicationDomain.Domain.NKS
            );
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
            logger.error(
                LOG_PREFIX + '.createThreadMessages EXIT | Thread not found | sessionId=' + session.Id,
                null,
                CRM_ApplicationDomain.Domain.NKS
            );
            return;
        }

        List<ConversationEntry> normalizedEntries = normalizeConversationEntries(wrapper.conversationEntries);

        List<ConversationEntry> chatbotMessages = new List<ConversationEntry>();
        List<ConversationEntry> userMessages = new List<ConversationEntry>();

        splitChatbotMessagesFromConversation(normalizedEntries, chatbotMessages, userMessages);

        if (!chatbotMessages.isEmpty()) {
            thread.CRM_Additional_Information__c = formatChatbotMessagesAsString(chatbotMessages);
        }

        List<Message__c> messagesToInsert = new List<Message__c>();

        if (session.NKS_Authentication_Timestamp__c != null) {
            messagesToInsert.add(createAuthEventMessage(session, thread));
        }

        for (ConversationEntry entry : userMessages) {
            if (entry != null && !String.isBlank(entry.messageText)) {
                messagesToInsert.add(createMessage(entry, session, thread));
            }
        }

        logger.info(
            LOG_PREFIX +
                '.createThreadMessages | normalizedEntries.size=' +
                normalizedEntries.size() +
                ' | chatbotMessages.size=' +
                chatbotMessages.size() +
                ' | userMessages.size=' +
                userMessages.size() +
                ' | messagesToInsert.size=' +
                messagesToInsert.size(),
            null,
            CRM_ApplicationDomain.Domain.NKS
        );

        if (!messagesToInsert.isEmpty()) {
            insertMessages(messagesToInsert);
        }

        updateThread(thread);
    }

    private static List<ConversationEntry> normalizeConversationEntries(List<ConversationEntry> entries) {
        List<ConversationEntry> normalizedEntries = new List<ConversationEntry>();

        for (ConversationEntry entry : entries) {
            if (entry == null || entry.messageText == null) {
                normalizedEntries.add(entry);
                continue;
            }

            String unescapedText = entry.messageText.unescapeHtml4();
            List<String> splitLines = unescapedText.split('\n');

            Boolean containsTranscriptLines = false;
            for (String line : splitLines) {
                String trimmedLine = line == null ? null : line.trim();
                if (
                    !String.isBlank(trimmedLine) &&
                    (trimmedLine.startsWith(PREFIX_FRIDA) ||
                    trimmedLine.startsWith(PREFIX_BRUKER) ||
                    trimmedLine.startsWith(PREFIX_VEILEDER))
                ) {
                    containsTranscriptLines = true;
                    break;
                }
            }

            if (!containsTranscriptLines || splitLines.size() == 1) {
                entry.messageText = unescapedText;
                normalizedEntries.add(entry);
                continue;
            }

            Integer lineIndex = 0;
            for (String line : splitLines) {
                String trimmedLine = line == null ? null : line.trim();
                if (String.isBlank(trimmedLine)) {
                    lineIndex++;
                    continue;
                }

                ConversationEntry splitEntry = cloneConversationEntry(entry);
                splitEntry.identifier = entry.identifier + '_' + String.valueOf(lineIndex);
                splitEntry.messageText = trimmedLine;
                splitEntry.sender = deriveSenderFromLinePrefix(trimmedLine, entry.sender);

                normalizedEntries.add(splitEntry);
                lineIndex++;
            }
        }

        logger.info(
            LOG_PREFIX +
                '.normalizeConversationEntries | inputSize=' +
                (entries == null ? 0 : entries.size()) +
                ' | normalizedSize=' +
                normalizedEntries.size(),
            null,
            CRM_ApplicationDomain.Domain.NKS
        );

        return normalizedEntries;
    }

    private static ConversationEntry cloneConversationEntry(ConversationEntry entry) {
        ConversationEntry cloneEntry = new ConversationEntry();
        cloneEntry.clientDuration = entry.clientDuration;
        cloneEntry.clientTimestamp = entry.clientTimestamp;
        cloneEntry.identifier = entry.identifier;
        cloneEntry.messageText = entry.messageText;
        cloneEntry.relatedRecords = entry.relatedRecords;
        cloneEntry.serverReceivedTimestamp = entry.serverReceivedTimestamp;

        if (entry.sender != null) {
            cloneEntry.sender = new Sender();
            cloneEntry.sender.appType = entry.sender.appType;
            cloneEntry.sender.role = entry.sender.role;
            cloneEntry.sender.subject = entry.sender.subject;
        }

        return cloneEntry;
    }

    private static Sender deriveSenderFromLinePrefix(String messageText, Sender originalSender) {
        Sender sender = new Sender();

        if (originalSender != null) {
            sender.appType = originalSender.appType;
            sender.role = originalSender.role;
            sender.subject = originalSender.subject;
        }

        if (messageText.startsWith(PREFIX_FRIDA)) {
            sender.role = 'System';
            sender.subject = null;
        } else if (messageText.startsWith(PREFIX_BRUKER)) {
            sender.role = 'EndUser';
        } else if (messageText.startsWith(PREFIX_VEILEDER)) {
            sender.role = 'Agent';
        }

        return sender;
    }

    private static void splitChatbotMessagesFromConversation(
        List<ConversationEntry> entries,
        List<ConversationEntry> chatbotMessages,
        List<ConversationEntry> userMessages
    ) {
        for (ConversationEntry entry : entries) {
            if (entry == null || String.isBlank(entry.messageText)) {
                continue;
            }

            String senderRole = entry.sender == null ? null : entry.sender.role;

            logger.info(
                LOG_PREFIX +
                    '.splitChatbotMessagesFromConversation | identifier=' +
                    entry.identifier +
                    ' | senderRole=' +
                    senderRole +
                    ' | messageText=' +
                    entry.messageText,
                null,
                CRM_ApplicationDomain.Domain.NKS
            );

            if (entry.messageText.startsWith(PREFIX_BRUKER) || entry.messageText.startsWith(PREFIX_VEILEDER)) {
                userMessages.add(entry);
            } else if (entry.messageText.startsWith(PREFIX_FRIDA)) {
                chatbotMessages.add(entry);
            } else if ('Agent'.equalsIgnoreCase(senderRole) || 'EndUser'.equalsIgnoreCase(senderRole)) {
                userMessages.add(entry);
            } else {
                chatbotMessages.add(entry);
            }
        }
    }

    private static Message__c createAuthEventMessage(MessagingSession msgSession, Thread__c thread) {
        String authText = msgSession.EndUserLanguage == 'en_US'
            ? 'Started authenticated chat'
            : 'Startet innlogget chat';

        return new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Type__c = 'Event',
            CRM_Sent_Date__c = msgSession.NKS_Authentication_Timestamp__c,
            CRM_Read__c = true,
            CRM_Message_Text__c = authText
        );
    }

    private static Message__c createMessage(ConversationEntry entry, MessagingSession session, Thread__c thread) {
        Message__c message = new Message__c();
        message.CRM_Thread__c = thread.Id;
        message.CRM_Message_Text__c = removeKnownPrefix(entry.messageText);
        message.CRM_Sent_Date__c = entry.serverReceivedTimestamp == null
            ? null
            : DateTime.newInstance(entry.serverReceivedTimestamp);
        message.CRM_Read__c = true;
        message.CRM_Type__c = 'Message';

        if (entry.messageText != null && entry.messageText.startsWith(PREFIX_VEILEDER)) {
            String senderSubject = normalizeUserId(entry.sender == null ? null : entry.sender.subject);
            User navUser = senderSubject == null ? null : navUserInfoByUserId.get(senderSubject);

            if (navUser != null) {
                message.CRM_From_User__c = navUser.Id;
                message.CRM_From_NAV_Unit__c = navUser.Department;
            }
        } else {
            message.CRM_From_Contact__c = session.EndUserContactId;
        }

        return message;
    }

    private static String removeKnownPrefix(String messageText) {
        if (String.isBlank(messageText)) {
            return messageText;
        }

        if (messageText.startsWith(PREFIX_FRIDA)) {
            return messageText.substring(PREFIX_FRIDA.length()).trim();
        }
        if (messageText.startsWith(PREFIX_BRUKER)) {
            return messageText.substring(PREFIX_BRUKER.length()).trim();
        }
        if (messageText.startsWith(PREFIX_VEILEDER)) {
            return messageText.substring(PREFIX_VEILEDER.length()).trim();
        }
        return messageText;
    }

    private static void insertMessages(List<Message__c> messages) {
        try {
            insert messages;
        } catch (Exception e) {
            logger.error(
                LOG_PREFIX +
                    '.insertMessages ERROR | message=' +
                    e.getMessage() +
                    ' | stack=' +
                    e.getStackTraceString() +
                    ' | payload=' +
                    JSON.serialize(messages),
                null,
                CRM_ApplicationDomain.Domain.NKS
            );
        }
    }

    private static void updateThread(Thread__c thread) {
        try {
            thread.CRM_isActive__c = false;
            thread.CRM_Closed_Date__c = System.now();
            update thread;
        } catch (Exception e) {
            logger.error(
                LOG_PREFIX +
                    '.updateThread ERROR | threadId=' +
                    thread.Id +
                    ' | message=' +
                    e.getMessage() +
                    ' | stack=' +
                    e.getStackTraceString(),
                null,
                CRM_ApplicationDomain.Domain.NKS
            );
        }
    }

    private static String formatChatbotMessagesAsString(List<ConversationEntry> entries) {
        List<String> formattedMessages = new List<String>();

        for (ConversationEntry entry : entries) {
            if (!String.isBlank(entry.messageText)) {
                formattedMessages.add(entry.messageText);
            }
        }

        return String.join(formattedMessages, '\n');
    }

    private static Map<String, User> getNavUserInfoByUserId() {
        Map<String, User> result = new Map<String, User>();

        for (User usr : [
            SELECT Id, Department, CRM_NAV_Ident__c
            FROM User
            WHERE
                ProfileId IN (SELECT Id FROM Profile WHERE Name LIKE 'NAV Kontaktsenter%')
                AND IsActive = TRUE
                AND CRM_NAV_Ident__c != NULL
                AND CRM_NAV_Ident__c != ''
        ]) {
            result.put(normalizeUserId(String.valueOf(usr.Id)), usr);
        }

        return result;
    }

    private static String normalizeUserId(String userIdValue) {
        if (String.isBlank(userIdValue)) {
            return null;
        }
        return userIdValue.length() >= 15 ? userIdValue.left(15) : userIdValue;
    }

    private static Thread__c getThreadDetails(Id messagingSessionId) {
        List<Thread__c> threads = [
            SELECT Id, CRM_Related_Object__c, CRM_Additional_Information__c, CRM_isActive__c, CRM_Closed_Date__c
            FROM Thread__c
            WHERE CRM_Related_Object__c = :messagingSessionId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return threads.isEmpty() ? null : threads[0];
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
