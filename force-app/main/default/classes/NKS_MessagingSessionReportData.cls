public with sharing class NKS_MessagingSessionReportData {
    public static void copyToReportingData(Set<Id> sessionIds) {
        if (sessionIds == null || sessionIds.isEmpty()) {
            return;
        }

        List<MessagingSession> sessions = [
            SELECT
                AcceptTime,
                AgentMessageCount,
                ChannelKey,
                ChannelName,
                ChannelType,
                ConversationId,
                CreatedById,
                CreatedDate,
                EndedByType,
                EndTime,
                EndUserMessageCount,
                LastModifiedById,
                LastModifiedDate,
                MessagingChannelId,
                Name,
                MessagingEndUserId,
                EndUserAccountId,
                EndUserContactId,
                Origin,
                PreviewDetails,
                OwnerId,
                StartTime,
                Status
            FROM MessagingSession
            WHERE Id IN :sessionIds
        ];

        List<ReportingData__c> reportingDataList = new List<ReportingData__c>();
        for (MessagingSession session : sessions) {
            Map<String, Object> fieldMap = new Map<String, Object>{
                'AcceptTime' => session.AcceptTime,
                'AgentMessageCount' => session.AgentMessageCount,
                'ChannelKey' => session.ChannelKey,
                'ChannelName' => session.ChannelName,
                'ChannelType' => session.ChannelType,
                'ConversationId' => session.ConversationId,
                'CreatedById' => session.CreatedById,
                'CreatedDate' => session.CreatedDate,
                'EndedByType' => session.EndedByType,
                'EndTime' => session.EndTime,
                'EndUserMessageCount' => session.EndUserMessageCount,
                'LastModifiedById' => session.LastModifiedById,
                'LastModifiedDate' => session.LastModifiedDate,
                'MessagingChannelId' => session.MessagingChannelId,
                'Name' => session.Name,
                'MessagingEndUserId' => session.MessagingEndUserId,
                'EndUserAccountId' => session.EndUserAccountId,
                'EndUserContactId' => session.EndUserContactId,
                'Origin' => session.Origin,
                'PreviewDetails' => session.PreviewDetails,
                'OwnerId' => session.OwnerId,
                'StartTime' => session.StartTime,
                'Status' => session.Status
            };

            reportingDataList.add(
                new ReportingData__c(CRM_Category__c = 'Chat', NKS_Messaging_Session__c = JSON.serialize(fieldMap))
            );
        }

        if (!reportingDataList.isEmpty()) {
            insert reportingDataList;
        }
    }
}
