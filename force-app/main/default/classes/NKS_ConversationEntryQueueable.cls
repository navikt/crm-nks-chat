public class NKS_ConversationEntryQueueable implements Queueable, Database.AllowsCallouts {
    private List<Id> messagingSessionIds;
    private Long startTimestamp;
    private Long endTimestamp;
    private String queryDirection;
    private Integer recordLimit;

    public NKS_ConversationEntryQueueable(
        List<Id> messagingSessionIds,
        Long startTimestamp,
        Long endTimestamp,
        String queryDirection,
        Integer recordLimit
    ) {
        this.messagingSessionIds = messagingSessionIds;
        this.startTimestamp = startTimestamp;
        this.endTimestamp = endTimestamp;
        this.queryDirection = queryDirection;
        this.recordLimit = recordLimit;
    }

    public void execute(QueueableContext context) {
        List<MessagingSession> sessions = [
            SELECT Id
            FROM MessagingSession
            WHERE Id IN :messagingSessionIds
        ];

        NKS_ConversationEntryController.convertConversationEntries(
            sessions,
            startTimestamp,
            endTimestamp,
            queryDirection,
            recordLimit
        );
    }
}
