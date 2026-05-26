// API Docs: https://developer.salesforce.com/docs/service/conversation-data-api/references/conversation-data-api-reference?meta=getConversationEntries
public class NKS_ConversationEntryService {
    private static final String API_VERSION = 'v66.0';

    public static HttpResponse getConversationEntryMessages(
        String conversationIdentifier,
        Long startTimestamp,
        Long endTimestamp,
        String queryDirection,
        Integer recordLimit
    ) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(
            'callout:Conversation_Data_API' +
            buildUrl(conversationIdentifier, startTimestamp, endTimestamp, queryDirection, recordLimit)
        );
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');

        return new Http().send(request);
    }

    private static String buildUrl(
        String conversationIdentifier,
        Long startTimestamp,
        Long endTimestamp,
        String queryDirection,
        Integer recordLimit
    ) {
        String url = '/conversation-entries?conversationIdentifier=' + conversationIdentifier + '&';

        if (startTimestamp != null) {
            url += 'startTimestamp=' + startTimestamp + '&';
        }
        if (endTimestamp != null) {
            url += 'endTimestamp=' + endTimestamp + '&';
        }
        if (queryDirection != null && (queryDirection == 'FROMEND' || queryDirection == 'FROMSTART')) {
            url += 'direction=' + queryDirection + '&';
        }
        if (recordLimit != null && recordLimit > 0 && recordLimit <= 1000) {
            url += 'limit=' + recordLimit;
        }
        if (url.endsWith('&') || url.endsWith('?')) {
            url = url.substring(0, url.length() - 1);
        }

        return url;
    }

    public static HttpResponse deleteConversationParticipantData(List<String> participantEntityIds) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(
            'callout:Conversation_Data_API' +
                '/conversation-participants?participantEntityId=' +
                String.join(participantEntityIds, ',') +
                '&cascadeLevel=FULL_CASCADE'
        );
        request.setMethod('DELETE');
        request.setHeader('Content-Type', 'application/json');

        return new Http().send(request);
    }
}
