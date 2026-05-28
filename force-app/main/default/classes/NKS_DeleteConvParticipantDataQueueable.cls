public with sharing class NKS_DeleteConvParticipantDataQueueable implements Queueable, Database.AllowsCallouts {
    private List<String> participantEntityIds;

    public NKS_DeleteConvParticipantDataQueueable(List<String> participantEntityIds) {
        this.participantEntityIds = participantEntityIds;
    }

    public void execute(QueueableContext context) {
        NKS_ConversationEntryService.deleteConversationParticipantData(participantEntityIds);
    }
}
