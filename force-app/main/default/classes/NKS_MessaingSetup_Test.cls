@IsTest
public with sharing class NKS_MessaingSetup_Test {
    @TestSetup
    static void makeData() {
        User per = (User) UTIL_TestDataFactory.createRecord(new User(FirstName = 'Per', LastName = 'paal'));
        Group g = new Group(Name = 'Messaging test skill', DeveloperName = 'NKS_Skill_Test', Type = 'Regular');
        insert g;
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

    @IsTest
    static void repeatedAssignmentAndRemovalAreIdempotent() {
        User user = [SELECT Id FROM User WHERE FirstName = 'Per' AND LastName = 'paal' LIMIT 1];
        Test.startTest();
        NKS_MessagingSetup.addMessagingPermissions(new List<User>{ user });
        NKS_MessagingSetup.addMessagingPermissions(new List<User>{ user });
        Assert.areEqual(
            1,
            [
                SELECT COUNT()
                FROM PermissionSetLicenseAssign
                WHERE
                    AssigneeId = :user.Id
                    AND PermissionSetLicense.DeveloperName = :NKS_MessagingSetup.messagingLicenseDeveloperName
            ]
        );
        Assert.areEqual(
            1,
            [
                SELECT COUNT()
                FROM PermissionSetAssignment
                WHERE AssigneeId = :user.Id AND PermissionSet.Name = :NKS_MessagingSetup.messagingPermissionSetName
            ]
        );
        NKS_MessagingSetup.removeMessagingPermissions(new List<User>{ user });
        NKS_MessagingSetup.removeMessagingPermissions(new List<User>{ user });
        Test.stopTest();
        Assert.areEqual(
            0,
            [
                SELECT COUNT()
                FROM PermissionSetLicenseAssign
                WHERE
                    AssigneeId = :user.Id
                    AND PermissionSetLicense.DeveloperName = :NKS_MessagingSetup.messagingLicenseDeveloperName
            ]
        );
        Assert.areEqual(
            0,
            [
                SELECT COUNT()
                FROM PermissionSetAssignment
                WHERE AssigneeId = :user.Id AND PermissionSet.Name = :NKS_MessagingSetup.messagingPermissionSetName
            ]
        );
    }

    @IsTest
    static void emptyUserListsDoNotChangeAssignments() {
        Integer licenses = [SELECT COUNT() FROM PermissionSetLicenseAssign];
        Integer permissions = [SELECT COUNT() FROM PermissionSetAssignment];
        Test.startTest();
        NKS_MessagingSetup.addMessagingPermissions(new List<User>());
        NKS_MessagingSetup.removeMessagingPermissions(new List<User>());
        Test.stopTest();
        Assert.areEqual(licenses, [SELECT COUNT() FROM PermissionSetLicenseAssign]);
        Assert.areEqual(permissions, [SELECT COUNT() FROM PermissionSetAssignment]);
    }
}
