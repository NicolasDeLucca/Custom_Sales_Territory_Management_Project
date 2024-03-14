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
    static void ThreeSalesRepsAtMostCanBeAssignedToAZipCodeByUpdateTest()
    {
        // Create three more territories and three more sales reps related with the first dealer account
        insertBaseUsers();
        insertBaseTerritories();
        updateTest();
    }

    @isTest
    static void ThreeSalesRepsAtMostCanBeAssignedToAZipCodeByInsertionTest()
    {
        // Create three more territories and three more sales reps related with the first dealer account
        insertBaseUsers();
        insertBaseTerritories();
        insertionTest();
    }

    @future
    private static void insertBaseTerritories()
    {
        User Owner3Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = 'testuser3@sunmotors.com'
            LIMIT 1 
        ];
        
        System.runAs(Owner3Test)
        {
            insert new Territory__c(
                Name = 'Territory test 3', 
                Zip_Code__c = TestFactory.ZIP_CODE_DEALER_TEST_1,
                Owner__c = Owner3Test.Id
            );
        }

        User Owner4Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = 'testuser4@sunmotors.com'
            LIMIT 1
        ];

        System.runAs(Owner4Test)
        {
            insert new Territory__c(
                Name = 'Territory test 4', 
                Zip_Code__c = TestFactory.ZIP_CODE_DEALER_TEST_1,
                Owner__c = Owner4Test.Id
            );
        }
    }

    @future
    private static void insertBaseUsers()
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
    private static void updateTest()
    {
        User Owner5Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = 'testuser5@sunmotors.com'
            LIMIT 1
        ];

        System.runAs(Owner5Test)
        {
            insert new Territory__c(
                Name = 'Territory test 5', 
                Zip_Code__c = TestFactory.ZIP_CODE_DEALER_TEST_2,
                Owner__c = Owner5Test.Id
            );

            Territory__c territory5Test = 
            [
                SELECT Id, Zip_Code__c, Owner__c
                FROM Territory__c 
                WHERE Name = 'Territory test 5'
                LIMIT 1
            ];

            try
            {
                territory5Test.Zip_Code__c = TestFactory.ZIP_CODE_DEALER_TEST_1;
                // should fail
                update territory5Test;
            }
            catch(DmlException e)
            {
                System.assert(e.getDmlMessage(0) == AutomobileDealerService.ZIP_CODE_ERROR_MESSAGE);
            }
        }
    }

    @future
    private static void insertionTest()
    {
        User Owner5Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = 'testuser5@sunmotors.com'
            LIMIT 1
        ];

        System.runAs(Owner5Test)
        { 
            try 
            {
                //should fail
                insert new Territory__c(
                    Name = 'Territory test 5', 
                    Zip_Code__c = TestFactory.ZIP_CODE_DEALER_TEST_1,
                    Owner__c = Owner5Test.Id
                ); 
            }
            catch (DmlException e)
            {
                System.assert(e.getDmlMessage(0) == AutomobileDealerService.ZIP_CODE_ERROR_MESSAGE);
            }
        }
    }
}