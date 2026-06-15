public class NKS_ConversationEntryController {
    private static LoggerUtility logger = new LoggerUtility('Messaging');
    private static final String LOG_PREFIX = 'NKS_ConversationEntryController';

    private static final String PREFIX_FRIDA = 'Frida:';
    private static final String PREFIX_BRUKER = 'Bruker:';
    private static final String PREFIX_VEILEDER = 'Veileder:';

    private static final String WELCOME_MARKER_NO = 'du snakker med ';
    private static final String CONVERSATION_TERMINATED_BY_END_USER = '---conversation terminated by end-user---';
    private static final String WELCOME_MARKER_EN = 'you\'re chatting with ';

    private static Map<String, User> navUserInfoByUserId = getNavUserInfoByUserId();

    public static void convertConversationEntries(
        List<MessagingSession> msgSessions,
        Long startTimestamp,
        Long endTimestamp,
        String queryDirection,
        Integer recordLimit
    ) {
        try {
            if (msgSessions == null || msgSessions.isEmpty()) {
                return;
            }

            List<Id> messagingSessionIds = new List<Id>();
            for (MessagingSession msgSession : msgSessions) {
                if (msgSession != null && msgSession.Id != null) {
                    messagingSessionIds.add(msgSession.Id);
                }
            }

            if (messagingSessionIds.isEmpty()) {
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

            for (MessagingSession session : messagingSessions) {
                try {
                    if (session.CRM_Authentication_Status__c != 'Completed') {
                        continue;
                    }

                    String conversationIdentifier = Test.isRunningTest()
                        ? '17978db9-ed91-4363-adcb-d1b581168eed'
                        : session.Conversation.ConversationIdentifier;

                    if (conversationIdentifier == null) {
                        logger.error(
                            LOG_PREFIX +
                                '.convertConversationEntries | conversationIdentifier is null' +
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
        try {
            HttpResponse response = NKS_ConversationEntryService.getConversationEntryMessages(
                conversationIdentifier,
                startTimestamp,
                endTimestamp,
                queryDirection,
                recordLimit
            );

            if (response.getStatusCode() != 200) {
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
                return;
            }

            ConversationEntryWrapper wrapper = (ConversationEntryWrapper) JSON.deserialize(
                response.getBody(),
                ConversationEntryWrapper.class
            );

            createThreadMessages(wrapper, session);
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

        for (ConversationEntry entry : wrapper.conversationEntries) {
            if (entry != null && entry.entryPayload?.abstractMessage?.staticContent != null) {
                StaticContent sc = entry.entryPayload.abstractMessage.staticContent;
                entry.messageText = sc.formatType == 'RichLink' ? sc.linkItem?.url : sc.text;
            }
        }

        List<ConversationEntry> normalizedEntries = normalizeConversationEntries(wrapper.conversationEntries);

        List<String> additionalInfoLines = new List<String>();
        List<Message__c> messagesToInsert = new List<Message__c>();

        Boolean agentChatStarted = false;
        Message__c welcomeMessageWithoutUser = null;

        for (ConversationEntry entry : normalizedEntries) {
            if (entry == null || String.isBlank(entry.messageText)) {
                continue;
            }

            if (!agentChatStarted && hasAgentChatStarted(entry)) {
                agentChatStarted = true;
            }

            if (!agentChatStarted) {
                additionalInfoLines.add(normalizeAdditionalInfoLine(entry));
                continue;
            }

            ConversationEntry messageEntry = normalizeEntryForMessageCreation(entry);
            if (isMessageEntry(messageEntry)) {
                Message__c msg = createMessage(messageEntry, session, thread);
                if (welcomeMessageWithoutUser == null && isAgentWelcomeMessage(entry) && msg.CRM_From_User__c == null) {
                    welcomeMessageWithoutUser = msg;
                }
                messagesToInsert.add(msg);
            }
        }

        if (welcomeMessageWithoutUser != null) {
            for (Message__c msg : messagesToInsert) {
                if (msg !== welcomeMessageWithoutUser && msg.CRM_From_User__c != null) {
                    welcomeMessageWithoutUser.CRM_From_User__c = msg.CRM_From_User__c;
                    welcomeMessageWithoutUser.CRM_From_NAV_Unit__c = msg.CRM_From_NAV_Unit__c;
                    break;
                }
            }
        }

        if (!additionalInfoLines.isEmpty()) {
            thread.CRM_Additional_Information__c = String.join(additionalInfoLines, '\n');
        }

        if (session.NKS_Authentication_Timestamp__c != null) {
            messagesToInsert.add(0, createAuthEventMessage(session, thread));
        }

        // Disable henvendelses cache for message insert as thread update will handle that
        MyTriggers.disable(MessageCacheHandler.class);
        if (!messagesToInsert.isEmpty()) {
            insertMessages(messagesToInsert);
        }

        updateThread(thread);
    }

    private static List<ConversationEntry> normalizeConversationEntries(List<ConversationEntry> entries) {
        List<ConversationEntry> normalizedEntries = new List<ConversationEntry>();

        for (ConversationEntry entry : entries) {
            if (entry == null || String.isBlank(entry.messageText)) {
                continue;
            }

            String unescapedText = entry.messageText.unescapeHtml4().replace('\r\n', '\n');
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
                entry.messageText = unescapedText.trim();
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

        return normalizedEntries;
    }

    private static ConversationEntry cloneConversationEntry(ConversationEntry entry) {
        ConversationEntry cloneEntry = new ConversationEntry();
        cloneEntry.clientDuration = entry.clientDuration;
        cloneEntry.clientTimestamp = entry.clientTimestamp;
        cloneEntry.identifier = entry.identifier;
        cloneEntry.messageText = entry.messageText;
        cloneEntry.relatedRecords = entry.relatedRecords;
        cloneEntry.transcriptedTimestamp = entry.transcriptedTimestamp;

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

    private static Boolean hasAgentChatStarted(ConversationEntry entry) {
        if (entry == null) {
            return false;
        }

        String senderRole = entry.sender == null ? null : entry.sender.role;
        return 'Agent'.equalsIgnoreCase(senderRole) || isAgentWelcomeMessage(entry);
    }

    private static Boolean isAgentWelcomeMessage(ConversationEntry entry) {
        if (entry == null || String.isBlank(entry.messageText)) {
            return false;
        }

        if ('EndUser'.equalsIgnoreCase(entry.sender?.role)) {
            return false;
        }

        String text = removeKnownPrefix(entry.messageText).unescapeHtml4().toLowerCase();

        return (text.contains('velkommen til chat med nav') && text.contains(WELCOME_MARKER_NO)) ||
            (text.contains('welcome to chat with nav') && text.contains(WELCOME_MARKER_EN));
    }

    private static ConversationEntry normalizeEntryForMessageCreation(ConversationEntry entry) {
        if (entry == null) {
            return null;
        }

        if (isAgentWelcomeMessage(entry)) {
            if (entry.sender == null) {
                entry.sender = new Sender();
            }
            entry.sender.role = 'Agent';
        }

        return entry;
    }

    private static Boolean isMessageEntry(ConversationEntry entry) {
        if (entry == null || String.isBlank(entry.messageText)) {
            return false;
        }

        String senderRole = entry.sender == null ? null : entry.sender.role;

        if (CONVERSATION_TERMINATED_BY_END_USER.equalsIgnoreCase(entry.messageText.trim())) {
            return false;
        }

        return 'Agent'.equalsIgnoreCase(senderRole) || 'EndUser'.equalsIgnoreCase(senderRole);
    }

    private static String normalizeAdditionalInfoLine(ConversationEntry entry) {
        if (entry == null || String.isBlank(entry.messageText)) {
            return null;
        }

        String text = entry.messageText.trim();

        if (text.startsWith(PREFIX_FRIDA) || text.startsWith(PREFIX_BRUKER) || text.startsWith(PREFIX_VEILEDER)) {
            return text;
        }

        String senderRole = entry.sender == null ? null : entry.sender.role;

        if ('EndUser'.equalsIgnoreCase(senderRole)) {
            return PREFIX_BRUKER + ' ' + text;
        }
        if ('Agent'.equalsIgnoreCase(senderRole)) {
            return PREFIX_VEILEDER + ' ' + text;
        }

        return PREFIX_FRIDA + ' ' + text;
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
        message.CRM_Sent_Date__c = entry.transcriptedTimestamp == null
            ? null
            : DateTime.newInstance(entry.transcriptedTimestamp);
        message.CRM_Read__c = true;
        message.CRM_Type__c = 'Message';

        String senderRole = entry.sender == null ? null : entry.sender.role;

        if ('Agent'.equalsIgnoreCase(senderRole)) {
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

        return messageText.trim();
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
        public Long transcriptedTimestamp;
        public EntryPayload entryPayload;
    }

    public class EntryPayload {
        public AbstractMessage abstractMessage;
    }

    public class AbstractMessage {
        public StaticContent staticContent;
    }

    public class StaticContent {
        public String formatType;
        public String text;
        public LinkItem linkItem;
    }

    public class LinkItem {
        public String url;
    }

    public class Sender {
        public String appType;
        public String role;
        public String subject;
    }

    public static void retryDeleteParticipantData(List<String> participantEntityIds) {
        List<MessagingSession> sessions = [
            SELECT Id
            FROM MessagingSession
            WHERE MessagingEndUserId IN :participantEntityIds
        ];
        Set<Id> sessionIds = new Set<Id>();
        for (MessagingSession session : sessions) {
            sessionIds.add(session.Id);
        }

        deleteSessionDataAndEnqueueCallout(sessionIds, participantEntityIds);
    }

    public static void deleteSessionDataAndEnqueueCallout(Set<Id> sessionIds, List<String> participantEntityIds) {
        if (Type.forName('EngagementAttendee') != null) {
            List<SObject> attendees = Database.query(
                'SELECT Id FROM EngagementAttendee WHERE EngagementId IN :sessionIds'
            );
            if (!attendees.isEmpty()) {
                delete attendees;
            }
        }
        if (Type.forName('EngagementTopic') != null) {
            List<SObject> topics = Database.query('SELECT Id FROM EngagementTopic WHERE EngagementId IN :sessionIds');
            if (!topics.isEmpty()) {
                delete topics;
            }
        }

        if (!participantEntityIds.isEmpty()) {
            System.enqueueJob(new NKS_DeleteConvParticipantDataQueueable(participantEntityIds));
        }
    }
}
