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
        User Owner1Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = :TestFactory.OWNER_USERNAME_TEST_1
        ];

        User Owner2Test = 
        [
            SELECT Id 
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
        }
        
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

        System.runAs(Owner1Test)
        {
            System.assertEquals(retrievedDealers[0].OwnerId, Owner1Test.Id);
        }

        System.runAs(Owner2Test)
        {
            System.assertEquals(retrievedDealers[1].OwnerId, Owner2Test.Id);
        }
    }

    @isTest
    static void fixingIncorrectOwnershipTest()
    {
        Account retrievedDealer = 
        [
            SELECT Id, BillingPostalCode 
            FROM Account
            WHERE Name = 'Dealer test 1'
            LIMIT 1  
        ];

        // Act
        
        retrievedDealer.BillingPostalCode = TestFactory.ZIP_CODE_DEALER_TEST_2;
        update retrievedDealer;

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

        User Owner2Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = :TestFactory.OWNER_USERNAME_TEST_2
        ];
        
         // Verify ownership is correctly updated

        System.runAs(Owner2Test)
        {
            System.assertEquals(retrievedDealer.OwnerId, Owner2Test.Id, 'Ownership was not updated correctly');
        } 
    }
}