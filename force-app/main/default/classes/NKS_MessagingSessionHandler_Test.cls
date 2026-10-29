@IsTest
private class NKS_MessagingSessionHandler_Test {
    @TestSetup
    static void setup() {
        NKS_MessagingTestFixture.createSession('Ended', true);
    }

    private static MessagingSession candidate(Integer index) {
        return new MessagingSession(
            Id = Id.valueOf('0Mw' + String.valueOf(index).leftPad(12, '0')),
            Status = 'Ended',
            EndTime = Datetime.now().addMinutes(-5),
            CRM_Authentication_Status__c = 'Completed'
        );
    }

    private static MessagingSession withField(MessagingSession session, String field, Object value) {
        Map<String, Object> fields = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(session));
        fields.put(field, value);
        return (MessagingSession) JSON.deserialize(JSON.serialize(fields), MessagingSession.class);
    }

    private static void assertDecision(MessagingSession session, MessagingSession oldSession, Boolean eligible) {
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ session.Id => oldSession };
        List<Id> expected = eligible ? new List<Id>{ session.Id } : new List<Id>();
        NKS_ConversationEntryQueueable job = NKS_MessagingSessionHandler.buildConversionJob(
            new List<MessagingSession>{ session },
            oldMap
        );
        Assert.areEqual(expected, job == null ? new List<Id>() : job.messagingSessionIds);
        NKS_MessagingSessionHandler handler = new NKS_MessagingSessionHandler();
        handler.records = new List<MessagingSession>{ session };
        Integer beforeJobs = Limits.getQueueableJobs();
        handler.onAfterUpdate(oldMap);
        Assert.areEqual(eligible ? 1 : 0, Limits.getQueueableJobs() - beforeJobs);
    }

    @IsTest
    static void endedAndInactiveAreEligible() {
        MessagingSession session = candidate(1);
        MessagingSession oldSession = session.clone(true);
        oldSession.CRM_Authentication_Status__c = 'Not Started';
        assertDecision(session, oldSession, true);
        session = candidate(2);
        oldSession = session.clone(true);
        session = withField(session, 'Status', 'Inactive');
        assertDecision(session, oldSession, true);
    }

    @IsTest
    static void ineligibleDecisionsNeverEnqueue() {
        MessagingSession session = candidate(1);
        MessagingSession oldSession = session.clone(true);
        session = withField(session, 'EndTime', null);
        assertDecision(session, oldSession, false);
        session = withField(session, 'EndTime', Datetime.now().addDays(1));
        assertDecision(session, oldSession, false);
        session = withField(session, 'EndTime', oldSession.EndTime);
        session.CRM_Authentication_Status__c = 'Not Started';
        assertDecision(session, oldSession, false);
        session = candidate(2);
        oldSession = session.clone(true);
        session = withField(session, 'Status', 'Active');
        assertDecision(session, oldSession, false);
        session = candidate(3);
        oldSession = session.clone(true);
        assertDecision(session, oldSession, false);
        session.Queue_Name__c = 'Unrelated update';
        assertDecision(session, oldSession, false);
    }

    @IsTest
    static void mixedBulkEnqueuesOneJobForAllEligibleIds() {
        List<MessagingSession> sessions = new List<MessagingSession>();
        Map<Id, SObject> oldMap = new Map<Id, SObject>();
        List<Id> expected = new List<Id>();
        for (Integer i = 1; i <= 200; i++) {
            MessagingSession session = candidate(i);
            MessagingSession oldSession = session.clone(true);
            oldSession.CRM_Authentication_Status__c = 'Not Started';
            if (Math.mod(i, 2) == 0) {
                session = withField(session, 'Status', Math.mod(i, 4) == 0 ? 'Inactive' : 'Ended');
                expected.add(session.Id);
            } else {
                session = withField(session, 'EndTime', null);
            }
            sessions.add(session);
            oldMap.put(session.Id, oldSession);
        }
        Assert.areEqual(expected, NKS_MessagingSessionHandler.buildConversionJob(sessions, oldMap).messagingSessionIds);
        Test.startTest();
        NKS_MessagingSessionHandler handler = new NKS_MessagingSessionHandler();
        handler.records = sessions;
        handler.onAfterUpdate(oldMap);
        Assert.areEqual(1, Limits.getQueueableJobs());
        Test.stopTest();
        Assert.areEqual(1, [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'NKS_ConversationEntryQueueable']);
    }

    @IsTest
    static void realTriggerEnqueuesOnceAndIgnoresUnrelatedUpdate() {
        MessagingSession session = [SELECT Id FROM MessagingSession LIMIT 1];
        Test.startTest();
        session.CRM_Authentication_Status__c = 'Completed';
        update session;
        Assert.areEqual(1, Limits.getQueueableJobs());
        session.Queue_Name__c = 'Unrelated update';
        update session;
        Assert.areEqual(1, Limits.getQueueableJobs());
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM Message__c], 'Enqueue is not conversion success');
        NKS_MessagingTestFixture.assertLogged('conversationIdentifier is null');
    }

    @IsTest
    static void invalidHandlerContextLogsFailureWithoutEnqueue() {
        NKS_MessagingSessionHandler handler = new NKS_MessagingSessionHandler();
        handler.records = new List<MessagingSession>{ candidate(1) };
        Test.startTest();
        handler.onAfterUpdate(null);
        Assert.areEqual(0, Limits.getQueueableJobs());
        Test.stopTest();
        NKS_MessagingTestFixture.assertLogged('NKS_MessagingSessionHandler.onAfterUpdate ERROR');
    }
}
