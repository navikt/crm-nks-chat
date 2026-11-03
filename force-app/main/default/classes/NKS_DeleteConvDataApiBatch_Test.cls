@IsTest
private class NKS_DeleteConvDataApiBatch_Test {
    @TestSetup
    static void setup() {
        MyTriggers.disable(NKS_MessagingSessionHandler.class);
        MessagingSession oldSession = NKS_MessagingTestFixture.createSession('Ended', false);
        MessagingSession boundarySession = NKS_MessagingTestFixture.createSession('Ended', false);
        MessagingSession startBoundarySession = NKS_MessagingTestFixture.createSession('Ended', false);
        MessagingSession recentSession = NKS_MessagingTestFixture.createSession('Ended', false);
        MessagingSession authenticated = NKS_MessagingTestFixture.createSession('Ended', false);
        MessagingSession accountSession = NKS_MessagingTestFixture.createSession('Ended', false);
        MessagingSession active = NKS_MessagingTestFixture.createSession('New', false);
        authenticated.CRM_Authentication_Status__c = 'Completed';
        update new MessagingEndUser(
            Id = accountSession.MessagingEndUserId,
            AccountId = UTIL_TestDataFactory.createRecord(new Account()).Id
        );
        update authenticated;
        Datetime boundary = Datetime.newInstance(Date.today().addDays(-2), Time.newInstance(23, 59, 59, 0));
        Test.setCreatedDate(oldSession.Id, boundary.addDays(-1));
        Test.setCreatedDate(boundarySession.Id, boundary);
        Test.setCreatedDate(
            startBoundarySession.Id,
            Datetime.newInstance(Date.today().addDays(-2), Time.newInstance(0, 0, 0, 0))
        );
        Test.setCreatedDate(
            recentSession.Id,
            Datetime.newInstance(Date.today().addDays(-1), Time.newInstance(0, 0, 0, 0))
        );
        for (MessagingSession session : new List<MessagingSession>{ authenticated, accountSession, active }) {
            Test.setCreatedDate(session.Id, boundary.addDays(-1));
        }
    }

    @IsTest
    static void realBatchHonorsRetentionBoundariesAndExclusions() {
        Set<Id> expectedIds = new Set<Id>();
        Map<Id, MessagingSession> expected = new Map<Id, MessagingSession>(
            [
                SELECT Id, MessagingEndUserId, Status, CreatedDate
                FROM MessagingSession
                WHERE
                    EndUserAccountId = NULL
                    AND CRM_Authentication_Status__c != 'Completed'
                    AND Status IN ('Ended', 'Inactive', 'Error')
                    AND CreatedDate <= N_DAYS_AGO:2
            ]
        );
        expectedIds.addAll(expected.keySet());
        Assert.areEqual(3, expectedIds.size(), 'Old, end-of-boundary-day, and start-of-boundary-day sessions qualify');
        Test.startTest();
        Id jobId = Database.executeBatch(new NKS_DeleteConvDataApiBatch(), 40);
        Test.stopTest();
        AsyncApexJob job = [SELECT Status, NumberOfErrors, JobItemsProcessed FROM AsyncApexJob WHERE Id = :jobId];
        Assert.areEqual('Completed', job.Status);
        Assert.areEqual(0, job.NumberOfErrors);
        Assert.areEqual(1, job.JobItemsProcessed);
        List<ReportingData__c> reports = [
            SELECT CRM_Category__c, NKS_Has_Messaging_Session__c, NKS_Messaging_Session_Id__c, NKS_Messaging_Session__c
            FROM ReportingData__c
        ];
        Assert.areEqual(3, reports.size());
        Set<Id> actualIds = new Set<Id>();
        for (ReportingData__c report : reports) {
            Id sessionId = (Id) report.NKS_Messaging_Session_Id__c;
            actualIds.add(sessionId);
            Assert.areEqual('Chat', report.CRM_Category__c);
            Assert.areEqual(true, report.NKS_Has_Messaging_Session__c);
            Map<String, Object> copied = (Map<String, Object>) JSON.deserializeUntyped(report.NKS_Messaging_Session__c);
            Assert.areEqual(expected.get(sessionId).Status, copied.get('Status'));
            Assert.areEqual(
                String.valueOf(expected.get(sessionId).MessagingEndUserId),
                copied.get('MessagingEndUserId')
            );
            Assert.areEqual(
                expected.get(sessionId).CreatedDate,
                (Datetime) JSON.deserialize(JSON.serialize(copied.get('CreatedDate')), Datetime.class)
            );
        }
        Assert.areEqual(expectedIds, actualIds);
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'NKS_DeleteConvParticipantDataQueueable']
        );
    }

    @IsTest
    static void rerunDoesNotDuplicateReportingOrEnqueue() {
        MessagingSession session = [
            SELECT Id, MessagingEndUserId
            FROM MessagingSession
            WHERE Status = 'Ended' AND CRM_Authentication_Status__c != 'Completed' AND EndUserAccountId = NULL
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        Test.setMock(
            HttpCalloutMock.class,
            new NKS_RequestMock(
                'callout:Conversation_Data_API/conversation-participants?participantEntityId=' +
                    session.MessagingEndUserId +
                    '&cascadeLevel=FULL_CASCADE',
                'DELETE',
                200,
                '{}'
            )
        );
        Test.startTest();
        NKS_DeleteConvDataApiBatch batch = new NKS_DeleteConvDataApiBatch();
        batch.execute(null, new List<MessagingSession>{ session });
        Assert.areEqual(1, Limits.getQueueableJobs());
        batch.execute(null, new List<MessagingSession>{ session });
        Assert.areEqual(1, Limits.getQueueableJobs());
        Test.stopTest();
        Assert.areEqual(1, [SELECT COUNT() FROM ReportingData__c WHERE NKS_Messaging_Session_Id__c = :session.Id]);
    }

    @IsTest
    static void nullParticipantCopiesReportWithoutEnqueue() {
        MessagingSession session = [SELECT Id FROM MessagingSession LIMIT 1];
        Test.startTest();
        new NKS_DeleteConvDataApiBatch()
            .execute(null, new List<MessagingSession>{ new MessagingSession(Id = session.Id) });
        Assert.areEqual(0, Limits.getQueueableJobs());
        Test.stopTest();
        Assert.areEqual(1, [SELECT COUNT() FROM ReportingData__c WHERE NKS_Messaging_Session_Id__c = :session.Id]);
    }

    @IsTest
    static void schedulerStartsBatch() {
        Test.startTest();
        Id jobId = System.schedule('Retention test', '0 0 * * * ?', new NKS_DeleteConvDataApiBatch());
        Test.stopTest();
        Assert.areEqual('0 0 * * * ?', [SELECT CronExpression FROM CronTrigger WHERE Id = :jobId].CronExpression);
        Assert.areEqual(
            1,
            [
                SELECT COUNT()
                FROM AsyncApexJob
                WHERE ApexClass.Name = 'NKS_DeleteConvDataApiBatch' AND JobType = 'BatchApex'
            ]
        );
    }
}
