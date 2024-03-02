@isTest
private class AutomobileDealerRepairmentTest
{
    @TestSetup
    static void setUpCommonTestData()
    {
        TestFactory.insertTerritoryManagementData();
    }

    @isTest
    static void correctOwnershipAssignmentTest()
    {
        Id OwnerId1Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = :TestFactory.OWNER_USERNAME_TEST_1
        ].Id;

        Id OwnerId2Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = :TestFactory.OWNER_USERNAME_TEST_2
        ].Id;
        
        // Create test automobile dealers correctly assigned to their territories

        insert new Account(
            Name = 'Dealer test 2', 
            BillingPostalCode = TestFactory.ZIP_CODE_DEALER_TEST_2, 
            OwnerId = OwnerId2Test
        );
        
        //Act

        Test.startTest();
        System.schedule(
            'Test job 1', 
            TestFactory.CRON_EXP_EVERYDAY_AT_MIDNIGHT, 
            new AutomobileDealerRepairment()
        );
        Test.stopTest();
        
        // Verify ownership remains unchanged

        List<Account> retrievedDealers = 
        [
            SELECT OwnerId
            FROM Account
        ];

        System.assertEquals(retrievedDealers[0].OwnerId, OwnerId1Test);
        System.assertEquals(retrievedDealers[1].OwnerId, OwnerId2Test);
    }

    @isTest
    static void fixingIncorrectOwnershipTest()
    {
        Account retrievedDealer = 
        [
            SELECT BillingPostalCode 
            FROM Account
            WHERE Name = 'Dealer test 1'
            LIMIT 1  
        ];

        retrievedDealer.BillingPostalCode = TestFactory.ZIP_CODE_DEALER_TEST_2;
        update retrievedDealer;

        insert new cstm_AccountHistory__c(
            Accounts__c = retrievedDealer.Id,
            Field__c = 'BillingPostalCode',
            OldValue__c = TestFactory.ZIP_CODE_DEALER_TEST_1
        );

        // Act
        Test.startTest();
        String jobId = System.schedule(
            'Test Job 2',
            TestFactory.CRON_EXP_EVERYDAY_AT_MIDNIGHT, 
            new AutomobileDealerRepairment()
        );
        Test.stopTest();

        retrievedDealer = 
        [
            SELECT OwnerId
            FROM Account
            WHERE Name = 'Dealer test 1'
            LIMIT 1  
        ];

        Id OwnerId2Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = :TestFactory.OWNER_USERNAME_TEST_2
        ].Id;
        
         // Verify ownership is correctly updated
        System.assertEquals(retrievedDealer.OwnerId, OwnerId2Test);
    }
}