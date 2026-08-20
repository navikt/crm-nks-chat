public with sharing class NKS_DeleteConvParticipantDataQueueable implements Queueable, Database.AllowsCallouts {
    private static LoggerUtility logger = new LoggerUtility('Messaging');
    private static final String LOG_PREFIX = 'NKS_DeleteConvParticipantDataQueueable';

    private List<String> participantEntityIds;

    public NKS_DeleteConvParticipantDataQueueable(List<String> participantEntityIds) {
        this.participantEntityIds = participantEntityIds;
    }

    public void execute(QueueableContext context) {
        try {
            HttpResponse response = NKS_ConversationEntryService.deleteConversationParticipantData(
                participantEntityIds
            );

            if (response.getStatusCode() != 200) {
                logger.error(
                    LOG_PREFIX +
                        '.execute | Failed to delete conversation participant data' +
                        ' | statusCode=' +
                        response.getStatusCode() +
                        ' | body=' +
                        response.getBody() +
                        ' | participantEntityIds=' +
                        String.join(participantEntityIds, ','),
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
}
