public class NKS_ConversationEntryService {
    private static final String API_VERSION = 'v62.0';
    private static final String API_CONFIG_NAME = 'CONVERSATION_ENTRY_CONNECT_REST_API';
    private static final String SERVICE_NAME = 'GET_CONVERSATION_ENTRIES';

    public static HttpResponse getConversationEntryMessages(
        String conversationIdentifier,
        Long startTimestamp,
        Long endTimestamp,
        String queryDirection,
        Integer recordLimit
    ) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Salesforce_Connect_Rest_API' + buildUrl(conversationIdentifier, startTimestamp, endTimestamp, queryDirection, recordLimit));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        Http http = new Http();
        return http.send(req);
    }
    
    private static String buildUrl(
        String conversationIdentifier,
        Long startTimestamp,
        Long endTimestamp,
        String queryDirection,
        Integer recordLimit
    ) {
        String url = '/services/data/' + API_VERSION + '/connect/conversation/' + conversationIdentifier + '/entries?';

        if (startTimestamp != null) {
            url += 'startTimestamp=' + startTimestamp + '&';
        }
        if (endTimestamp != null) {
            url += 'endTimestamp=' + endTimestamp + '&';
        }
        if (queryDirection != null && (queryDirection == 'FromEnd' || queryDirection == 'FromStart')) {
            url += 'queryDirection=' + queryDirection + '&';
        }
        if (recordLimit != null && recordLimit > 0 && recordLimit <= 1000) {
            url += 'recordLimit=' + recordLimit;
        }
        if (url.endsWith('&') || url.endsWith('?')) {
            url = url.substring(0, url.length() - 1);
        }

        return url;
    }
}
