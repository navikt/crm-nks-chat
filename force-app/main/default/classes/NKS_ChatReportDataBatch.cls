/**
 * @description       :
 * @author            : mamikals
 * @group             :
 * @last modified on  : 24-01-2023
 * @last modified by  : mamikals
 **/
public with sharing class NKS_ChatReportDataBatch implements Database.Batchable<sObject> {
    public NKS_ChatReportDataBatch() {
        this.query = 'Select Id, Typeof Owner WHEN User THEN Department WHEN Group THEN Name END from livechatTranscript where owner.Type=\'User\' and status=\'Completed\'';
    }
    public NKS_ChatReportDataBatch(String query) {
        this.query = query;
    }
    private final String query;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<LiveChatTranscript> scope) {
        Map<Id, LiveChatTranscript> transMap = new Map<Id, LiveChatTranscript>();
        transMap.putAll(scope);

        List<ReportingData__c> reportedChats = [
            SELECT NKS_Related_Record__c
            FROM ReportingData__c
            WHERE CRM_Category__c = 'Chat' AND NKS_Related_Record__c IN :transMap.keySet()
        ];
        Set<String> reportedChatIds = new Set<String>();
        for (ReportingData__c report : reportedChats) {
            reportedChatIds.add(report.NKS_Related_Record__c);
        }

        List<ReportingData__c> finishedList = new List<ReportingData__c>();
        for (Id currentId : transMap.keySet()) {
            if (reportedChatIds.contains(currentId))
                continue;
            LiveChatTranscript trans = transMap.get(currentId);
            ReportingData__c report = new ReportingData__c(CRM_Category__c = 'Chat');
            report.NKS_Related_Record__c = currentId;
            User veileder = (User) trans.owner;
            report.CRM_NavUnit__c = veileder.Department;
            finishedList.add(report);
        }
        insert finishedList;
    }

    public void finish(Database.BatchableContext BC) {
    }
}
