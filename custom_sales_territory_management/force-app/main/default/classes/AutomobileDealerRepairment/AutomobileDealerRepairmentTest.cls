@isTest
private class AutomobileDealerRepairmentTest
{
    static final String CRON_EXP_EVERYDAY_AT_MIDNIGHT = '0 0 0 * * ?';
    static final String ZIP_CODE_DEALER_TEST_1 = '91001';
    static final String ZIP_CODE_DEALER_TEST_2 = '91002';
    
    @TestSetup
    static void setUpCommonTestData()
    {
        // Insertion of two users and two territories

        insert new User(
            FirstName = 'Test', 
            LastName = 'User 1',
            Email = 'testuser1@gmail.com',
            Username = 'testuser1@sunmotors.com',
            Alias = 'user1',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            ProfileId = 
            [
                SELECT Id 
                FROM Profile 
                WHERE Name = 'Standard User'
            ].Id
        );

        insert new User(
            FirstName = 'Test', 
            LastName = 'User 2',
            Email = 'testuser2@gmail.com',
            Username = 'testuser2@sunmotors.com',
            Alias = 'user2',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = 
            [
                SELECT Id 
                FROM Profile 
                WHERE Name = 'System Administrator'
            ].Id
        );

        Id OwnerId1Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = 'testuser1@sunmotors.com'
        ].Id;

        insert new Territory__c(
            Name = 'Territory test 1', 
            Zip_Code__c = ZIP_CODE_DEALER_TEST_1, 
            Owner__c = OwnerId1Test
        ); 
        
        Id OwnerId2Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = 'testuser2@sunmotors.com'
        ].Id;

        insert new Territory__c(
            Name = 'Territory test 2', 
            Zip_Code__c = ZIP_CODE_DEALER_TEST_2, 
            Owner__c = OwnerId2Test
        );
    }

    @isTest
    static void correctOwnershipAssignmentTest()
    {
        Id OwnerId1Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = 'testuser1@sunmotors.com'
        ].Id;

        Id OwnerId2Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = 'testuser2@sunmotors.com'
        ].Id;
        
        // Create test automobile dealers correctly assigned to their territories

        List<Account> dealers = new List<Account>();
        dealers.add(
            new Account(
                Name = 'Dealer test 1', 
                BillingPostalCode = ZIP_CODE_DEALER_TEST_1, 
                OwnerId = OwnerId1Test
            )
        );
        dealers.add(
            new Account(
                Name = 'Dealer test 2', 
                BillingPostalCode = ZIP_CODE_DEALER_TEST_2, 
                OwnerId = OwnerId2Test
            )
        );
        insert dealers;
        
        //Act

        Test.startTest();
        System.schedule(
            'Test job 1', 
            CRON_EXP_EVERYDAY_AT_MIDNIGHT, 
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
        Id OwnerId1Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = 'testuser1@sunmotors.com'
        ].Id;

        insert new Account(
            Name = 'Dealer test', 
            BillingPostalCode = ZIP_CODE_DEALER_TEST_1,
            OwnerId = OwnerId1Test
        );

        Account retrievedDealer = 
        [
            SELECT BillingPostalCode 
            FROM Account
            WHERE Name = 'Dealer test'
            LIMIT 1  
        ];

        retrievedDealer.BillingPostalCode = ZIP_CODE_DEALER_TEST_2;
        update retrievedDealer;

        insert new cstm_AccountHistory__c(
            Accounts__c = retrievedDealer.Id,
            Field__c = 'BillingPostalCode',
            OldValue__c = ZIP_CODE_DEALER_TEST_1
        );

        // Act
        Test.startTest();
        String jobId = System.schedule(
            'Test Job 2',
            CRON_EXP_EVERYDAY_AT_MIDNIGHT, 
            new AutomobileDealerRepairment()
        );
        Test.stopTest();

        retrievedDealer = 
        [
            SELECT OwnerId
            FROM Account
            WHERE Name = 'Dealer test'
            LIMIT 1  
        ];

        Id OwnerId2Test = 
        [
            SELECT Id 
            FROM User 
            WHERE Username = 'testuser2@sunmotors.com'
        ].Id;
        
         // Verify ownership is correctly updated
        System.assertEquals(retrievedDealer.OwnerId, OwnerId2Test);
    }
}