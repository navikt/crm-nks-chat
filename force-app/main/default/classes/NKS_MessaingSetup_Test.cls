@IsTest
public with sharing class NKS_MessaingSetup_Test {
    @TestSetup
    static void makeData() {
        User per = (User) UTIL_TestDataFactory.createRecord(new User(FirstName = 'Per', LastName = 'paal'));
        Group g = [SELECT DeveloperName FROM Group WHERE DeveloperName LIKE 'NKS_Skill_%' LIMIT 1];
        GroupMember member = new groupMember();
        member.UserOrGroupId = per.Id;
        member.GroupId = g.Id;
        insert member;
    }

    @IsTest
    static void testGetUsersWithSkillGroup() {
        Test.startTest();
        List<User> users = NKS_MessagingSetup.getUsersWithSkillGroup();
        Test.stopTest();
        Assert.areNotEqual(0, users.size(), 'Did not find user with skill group');
    }

    @IsTest
    static void testAddMessagingPermissions() {
        List<User> users = [SELECT Id FROM User WHERE Name = 'Per Paal'];
        List<PermissionSetAssignment> oldPermAssign = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :users[0].Id AND PermissionSet.Name = :NKS_MessagingSetup.messagingPermissionSetName
        ];
        List<PermissionSetLicenseAssign> oldLicenseAssign = [
            SELECT Id
            FROM PermissionSetLicenseAssign
            WHERE
                AssigneeId = :users[0].Id
                AND PermissionSetLicense.DeveloperName = :NKS_MessagingSetup.messagingLicenseDeveloperName
        ];
        Test.startTest();
        NKS_MessagingSetup.addMessagingPermissions(users);
        Test.stopTest();
        List<PermissionSetAssignment> newPermAssign = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :users[0].Id AND PermissionSet.Name = :NKS_MessagingSetup.messagingPermissionSetName
        ];
        List<PermissionSetLicenseAssign> newLicenseAssign = [
            SELECT Id
            FROM PermissionSetLicenseAssign
            WHERE
                AssigneeId = :users[0].Id
                AND PermissionSetLicense.DeveloperName = :NKS_MessagingSetup.messagingLicenseDeveloperName
        ];
        Assert.areNotEqual(oldLicenseAssign.size(), newLicenseAssign.size(), 'Did not assign license');
        Assert.areNotEqual(oldPermAssign.size(), newPermAssign.size(), 'Did not assign permission');
    }

    @IsTest
    static void testRemoveMessagingPermissions() {
        List<User> users = [SELECT Id FROM User WHERE Name = 'Per Paal'];
        NKS_MessagingSetup.addMessagingPermissions(users);
        List<PermissionSetAssignment> oldPermAssign = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :users[0].Id AND PermissionSet.Name = :NKS_MessagingSetup.messagingPermissionSetName
        ];
        List<PermissionSetLicenseAssign> oldLicenseAssign = [
            SELECT Id
            FROM PermissionSetLicenseAssign
            WHERE
                AssigneeId = :users[0].Id
                AND PermissionSetLicense.DeveloperName = :NKS_MessagingSetup.messagingLicenseDeveloperName
        ];
        Test.startTest();
        NKS_MessagingSetup.removeMessagingPermissions(users);
        Test.stopTest();
        List<PermissionSetAssignment> newPermAssign = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :users[0].Id AND PermissionSet.Name = :NKS_MessagingSetup.messagingPermissionSetName
        ];
        List<PermissionSetLicenseAssign> newLicenseAssign = [
            SELECT Id
            FROM PermissionSetLicenseAssign
            WHERE
                AssigneeId = :users[0].Id
                AND PermissionSetLicense.DeveloperName = :NKS_MessagingSetup.messagingLicenseDeveloperName
        ];
        Assert.areNotEqual(oldLicenseAssign.size(), newLicenseAssign.size(), 'Did not remove license');
        Assert.areNotEqual(oldPermAssign.size(), newPermAssign.size(), 'Did not remove permission');
    }

    @IsTest
    static void testAddMessagingPermissionsWithTooManyUsers() {
        List<User> users = [SELECT Id FROM User WHERE Name = 'Per Paal'];
        PermissionSetLicense messagingLicense = [
            SELECT TotalLicenses
            FROM PermissionSetLicense
            WHERE DeveloperName = :NKS_MessagingSetup.messagingLicenseDeveloperName
            LIMIT 1
        ];
        for (Integer i = 0; i < messagingLicense.TotalLicenses; i++) {
            users.add(new User());
        }
        List<PermissionSetLicenseAssign> oldLicenseAssign = [
            SELECT Id
            FROM PermissionSetLicenseAssign
            WHERE PermissionSetLicense.DeveloperName = :NKS_MessagingSetup.messagingLicenseDeveloperName
        ];
        Test.startTest();
        NKS_MessagingSetup.addMessagingPermissions(users);
        Test.stopTest();
        List<PermissionSetLicenseAssign> newLicenseAssign = [
            SELECT Id
            FROM PermissionSetLicenseAssign
            WHERE PermissionSetLicense.DeveloperName = :NKS_MessagingSetup.messagingLicenseDeveloperName
        ];
        Assert.areEqual(
            oldLicenseAssign.size(),
            newLicenseAssign.size(),
            'Assgined licencese when user list was too big'
        );
    }
}
