@isTest
private class AutomobileDealerServiceTest
{
    @TestSetup
    static void setUpCommonTestData()
    {
        TestFactory.insertTerritoryManagementData();

        User Owner2Test = 
        [
            SELECT Id, FirstName, LastName
            FROM User 
            WHERE Username = :TestFactory.OWNER_USERNAME_TEST_2
        ];

        // Create test automobile dealers correctly assigned to their territories

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

    @isTest
    static void correctOpportunitiesAndContactsOwnershipAssignmentTest()
    {
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
}