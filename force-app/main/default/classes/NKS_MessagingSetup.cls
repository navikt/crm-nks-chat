public with sharing class NKS_MessagingSetup {
    public final static String messagingLicenseDeveloperName = 'EmbeddedServiceMessagingUserPsl';
    public final static String messagingPermissionSetName = 'NKS_Messaging_Permissions';

    public static List<User> getUsersWithSkillGroup() {
        return [
            SELECT Id
            FROM User
            WHERE
                Id IN (
                    SELECT UserOrGroupId
                    FROM GroupMember
                    WHERE
                        Group.DeveloperName LIKE 'NKS_Skill_%'
                        OR Group.DeveloperName LIKE 'HOT_ServicetjenestenVeiledere%'
                )
        ];
    }

    public static List<User> getUsersMissingMessagingLicense() {
        return [
            SELECT Id, Name, Profile.UserLicense.Name
            FROM User
            WHERE
                Id IN (
                    SELECT UserOrGroupId
                    FROM GroupMember
                    WHERE
                        Group.DeveloperName LIKE 'NKS_Skill_%'
                        OR Group.DeveloperName LIKE 'HOT_ServicetjenestenVeiledere%'
                )
                AND Id NOT IN (
                    SELECT AssigneeId
                    FROM PermissionSetLicenseAssign
                    WHERE PermissionSetLicense.DeveloperName = :messagingLicenseDeveloperName
                )
        ];
    }

    public static void addMessagingPermissions(List<User> users) {
        LoggerUtility logger = new LoggerUtility('Messaging');
        PermissionSetLicense messagingLicense = [
            SELECT DeveloperName, TotalLicenses, UsedLicenses, Id
            FROM PermissionSetLicense
            WHERE DeveloperName = :messagingLicenseDeveloperName
            LIMIT 1
        ];
        if (messagingLicense == null)
            return;
        List<PermissionSetLicenseAssign> assignedPermissionLicenses = new List<PermissionSetLicenseAssign>();
        Set<Id> userIds = new Set<Id>();
        for (User user : users) {
            userIds.add(user.Id);
        }
        Set<Id> alreadyAssignedIds = new Set<Id>();
        for (PermissionSetLicenseAssign existing : [
            SELECT AssigneeId
            FROM PermissionSetLicenseAssign
            WHERE PermissionSetLicense.DeveloperName = :messagingLicenseDeveloperName AND AssigneeId IN :userIds
        ]) {
            alreadyAssignedIds.add(existing.AssigneeId);
        }
        List<User> usersToAssign = new List<User>();
        for (User user : users) {
            if (!alreadyAssignedIds.contains(user.Id)) {
                usersToAssign.add(user);
            }
        }
        if (messagingLicense.TotalLicenses > messagingLicense.UsedLicenses + usersToAssign.size()) {
            for (User user : usersToAssign) {
                PermissionSetLicenseAssign permission = new PermissionSetLicenseAssign();
                permission.AssigneeId = user.Id;
                permission.PermissionSetLicenseId = messagingLicense.Id;
                assignedPermissionLicenses.add(permission);
            }
        } else {
            logger.error(
                'Could not assign messagingLicense ' +
                    messagingLicense.DeveloperName +
                    ' to ' +
                    usersToAssign.size() +
                    ' users, as there were only ' +
                    (messagingLicense.TotalLicenses - messagingLicense.UsedLicenses) +
                    ' left.',
                messagingLicense,
                CRM_ApplicationDomain.Domain.NKS
            );
            logger.publish();
            return;
        }
        List<Database.SaveResult> licenseResults = Database.insert(assignedPermissionLicenses, false);

        Set<Id> successfulUserIds = new Set<Id>();
        successfulUserIds.addAll(alreadyAssignedIds);
        for (Integer i = 0; i < licenseResults.size(); i++) {
            if (licenseResults[i].isSuccess()) {
                successfulUserIds.add(assignedPermissionLicenses[i].AssigneeId);
            } else {
                logger.warning(
                    'Could not assign messagingLicense ' +
                        messagingLicense.DeveloperName +
                        ' to user ' +
                        assignedPermissionLicenses[i].AssigneeId +
                        ': ' +
                        licenseResults[i].getErrors()[0].getMessage(),
                    messagingLicense,
                    CRM_ApplicationDomain.Domain.NKS
                );
            }
        }

        if (successfulUserIds.isEmpty())
            return;

        List<PermissionSetAssignment> assignedPermissions = new List<PermissionSetAssignment>();
        PermissionSet messagingPermission = [
            SELECT Id, Name
            FROM PermissionSet
            WHERE Name = :messagingPermissionSetName
            LIMIT 1
        ];
        Set<Id> alreadyAssignedPermissionIds = new Set<Id>();
        for (PermissionSetAssignment existing : [
            SELECT AssigneeId
            FROM PermissionSetAssignment
            WHERE PermissionSet.Name = :messagingPermissionSetName AND AssigneeId IN :successfulUserIds
        ]) {
            alreadyAssignedPermissionIds.add(existing.AssigneeId);
        }
        for (User user : users) {
            if (!successfulUserIds.contains(user.Id) || alreadyAssignedPermissionIds.contains(user.Id))
                continue;
            PermissionSetAssignment permissioner = new PermissionSetAssignment();
            permissioner.AssigneeId = user.Id;
            permissioner.PermissionSetId = messagingPermission.Id;
            assignedPermissions.add(permissioner);
        }
        Database.insert(assignedPermissions, false);
        logger.publish();
    }

    public static void removeMessagingPermissions(List<User> users) {
        List<Id> userIds = new List<Id>();
        for (User user : users) {
            userIds.add(user.Id);
        }
        delete [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE PermissionSet.Name = :messagingPermissionSetName AND AssigneeId IN :userIds
        ];
        delete [
            SELECT Id
            FROM PermissionSetLicenseAssign
            WHERE PermissionSetLicense.DeveloperName = :messagingLicenseDeveloperName AND AssigneeId IN :userIds
        ];
    }
}
