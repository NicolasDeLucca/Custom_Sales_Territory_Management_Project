@isTest
private class AutomobileDealerServiceTest
{
    @TestSetup
    static void setUpCommonTestData()
    {
        TestFactory.insertTerritoryManagementData();
    }

    @isTest
    static void correctOpportunitiesAndContactsOwnershipAssignmentTest()
    {
        User Owner2Test = 
        [
            SELECT Id, FirstName, LastName
            FROM User 
            WHERE Username = :TestFactory.OWNER_USERNAME_TEST_2
        ];

        // Create test automobile dealers correctly assigned to their territories
        System.runAs(Owner2Test)
        {
            insert new Account(
                Name = 'Dealer test 2', 
                BillingPostalCode = TestFactory.ZIP_CODE_DEALER_TEST_2, 
                OwnerId = Owner2Test.Id
            );

            Id accountId = 
            [
                SELECT Id 
                FROM Account 
                WHERE OwnerId = :Owner2Test.Id
            ].Id;

            // Create a related contact for the second account

            Contact newContact = new Contact(
                FirstName = Owner2Test.FirstName, 
                LastName = Owner2Test.LastName, 
                AccountId = accountId,
                OwnerId = Owner2Test.Id
            );
            insert newContact;

            // Create a related open opportunity for the second account
            
            insert new Opportunity(
                Name = 'Opportunity test', 
                StageName = 'Prospecting', 
                CloseDate = Date.today().addDays(1), 
                AccountId = accountId, 
                OwnerId = Owner2Test.Id
            );
        }

        Account dealer1Test = 
        [
            SELECT Id, OwnerId
            FROM Account 
            WHERE BillingPostalCode = :TestFactory.ZIP_CODE_DEALER_TEST_1
            LIMIT 1
        ];

        Account dealer2Test = 
        [
            SELECT Id, OwnerId
            FROM Account 
            WHERE BillingPostalCode = :TestFactory.ZIP_CODE_DEALER_TEST_2
            LIMIT 1
        ];

        Territory__c territoryToChange = 
        [
            SELECT Id 
            FROM Territory__c 
            WHERE Owner__c = :dealer1Test.OwnerId
            AND Zip_Code__c = :TestFactory.ZIP_CODE_DEALER_TEST_1
        ];

        // retrieve the related open opportunity and contact of the first dealer

        List<Contact> relatedContacts = 
        [
            SELECT Id, OwnerId
            FROM Contact
            WHERE AccountId = :dealer1Test.Id
        ];

        List<Opportunity> openRelatedOpportunities =
        [
            SELECT Id, OwnerId
            FROM Opportunity
            WHERE AccountId = :dealer1Test.Id
            AND StageName = 'Prospecting'
        ];

        // The first dealer should not have any related open opportunities or contacts
        System.assertEquals(relatedContacts.size(), 0);
        System.assertEquals(openRelatedOpportunities.size(), 0);

        // Act
        
        Test.startTest();

        territoryToChange.Owner__c = dealer2Test.OwnerId;
        update territoryToChange;

        Test.stopTest();

        // Verify the related open opportunities and contacts of the territory owner have been correctly assigned

        Opportunity openRelatedOpportunity = 
        [
            SELECT Id, OwnerId
            FROM Opportunity 
            WHERE AccountId = :dealer2Test.Id
            AND StageName = 'Prospecting'
            LIMIT 1
        ];
        
        Contact relatedContact = 
        [
            SELECT Id, OwnerId
            FROM Contact 
            WHERE AccountId = :dealer2Test.Id
            LIMIT 1
        ];
        
        System.assertEquals(openRelatedOpportunity.OwnerId, dealer2Test.OwnerId);
        System.assertEquals(relatedContact.OwnerId, dealer2Test.OwnerId);
    }

    @isTest
    static void ThreeSalesRepsAtMostCanBeAssignedToAZipCodeTest()
    {
        // Create three more territories and three more sales reps related with the first dealer account
        insertNewUsers();
        insertTerritories();

        // Act
        Test.startTest();
        relatedTerritories();
        Test.stopTest();

        // Verify
        List<Territory__c> territoriesWithFirstAccount = 
        [
            SELECT Id, Owner__c
            FROM Territory__c 
            WHERE Zip_Code__c = :TestFactory.ZIP_CODE_DEALER_TEST_1
        ];
        System.assertEquals(territoriesWithFirstAccount.size(), 3);
    }

    @future
    private static void insertTerritories()
    {
        insert new Territory__c(
            Name = 'Territory test 3', 
            Zip_Code__c = TestFactory.ZIP_CODE_DEALER_TEST_1
        );

        insert new Territory__c(
            Name = 'Territory test 4', 
            Zip_Code__c = TestFactory.ZIP_CODE_DEALER_TEST_1
        );

        insert new Territory__c(
            Name = 'Territory test 5', 
            Zip_Code__c = TestFactory.ZIP_CODE_DEALER_TEST_2
        );
    }

    @future
    private static void insertNewUsers()
    {
        Id appSubscriptionUserId = 
        [
            SELECT Id 
            FROM Profile 
            WHERE Name = 'Force.com - App Subscription User'
        ].Id;

        Id westernSalesTeamId =
        [
            SELECT Id 
            FROM UserRole 
            WHERE Name = 'Western Sales Team'
        ].Id;

        insert new User(
            FirstName = 'Test', 
            LastName = 'User 3',
            Email = 'testuser3@gmail.com',
            Username = 'testuser3@sunmotors.com',
            Alias = 'user3',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            ProfileId = 
            [
                SELECT Id 
                FROM Profile 
                WHERE Name = 'Force.com - Free User'
            ].Id,
            UserRoleId = westernSalesTeamId
        );

        insert new User(
            FirstName = 'Test', 
            LastName = 'User 4',
            Email = 'testuser4@gmail.com',
            Username = 'testuser4@sunmotors.com',
            Alias = 'user4',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = appSubscriptionUserId,
            UserRoleId = westernSalesTeamId
        );

        insert new User(
            FirstName = 'Test', 
            LastName = 'User 5',
            Email = 'testuser5@gmail.com',
            Username = 'testuser5@sunmotors.com',
            Alias = 'user5',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = appSubscriptionUserId,
            UserRoleId = westernSalesTeamId
        );
    }

    @future
    private static void relatedTerritories()
    {
        User Owner3Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = 'testuser3@sunmotors.com'
            LIMIT 1 
        ];

        Territory__c territory3Test = 
        [
            SELECT Id, Zip_Code__c, Owner__c
            FROM Territory__c 
            WHERE Name = 'Territory test 3'
            LIMIT 1
        ];
        
        System.runAs(Owner3Test)
        {
            territory3Test.Owner__c = Owner3Test.Id;
            update territory3Test;
        }

        User Owner4Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = 'testuser4@sunmotors.com'
            LIMIT 1
        ];

        Territory__c territory4Test = 
        [
            SELECT Id, Zip_Code__c, Owner__c
            FROM Territory__c 
            WHERE Name = 'Territory test 4'
            LIMIT 1
        ];

        System.runAs(Owner4Test)
        {
            territory4Test.Owner__c = Owner4Test.Id;
            update territory4Test;
        }

        User Owner5Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = 'testuser5@sunmotors.com'
            LIMIT 1
        ];

        Territory__c territory5Test = 
        [
            SELECT Id, Zip_Code__c, Owner__c
            FROM Territory__c 
            WHERE Name = 'Territory test 5'
            LIMIT 1
        ];

        System.runAs(Owner5Test)
        {
            territory5Test.Owner__c = Owner5Test.Id;
            update territory5Test;
            territory5Test = 
            [
                SELECT Id, Zip_Code__c, Owner__c
                FROM Territory__c 
                WHERE Name = 'Territory test 5'
                LIMIT 1
            ];
            // should fail
            territory5Test.Zip_Code__c = TestFactory.ZIP_CODE_DEALER_TEST_1;
            update territory5Test;
        }
    }
        
}