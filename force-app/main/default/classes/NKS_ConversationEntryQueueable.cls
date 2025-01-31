public with sharing class NKS_ConversationEntryQueueable implements Queueable, Database.AllowsCallouts {
    List<MessagingSession> messagingSessions;
    Long startTimestamp;
    Long endTimestamp;
    String queryDirection;
    Integer recordLimit;

    public NKS_ConversationEntryQueueable(
        List<MessagingSession> messagingSessions,
        Long startTimestamp,
        Long endTimestamp,
        String queryDirection,
        Integer recordLimit
    ) {
        this.messagingSessions = messagingSessions;
        this.startTimestamp = startTimestamp;
        this.endTimestamp = endTimestamp;
        this.queryDirection = queryDirection;
        this.recordLimit = recordLimit;
    }

    public void execute(QueueableContext context) {
        NKS_ConversationEntryController.convertConversationEntries(
            messagingSessions,
            startTimestamp,
            endTimestamp,
            queryDirection,
            recordLimit
        );
    }
}
