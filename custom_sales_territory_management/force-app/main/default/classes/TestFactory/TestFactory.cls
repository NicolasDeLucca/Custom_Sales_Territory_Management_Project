public class TestFactory
{
    public static final String CRON_EXP_EVERYDAY_AT_MIDNIGHT = '0 0 0 * * ?';
    public static final String OWNER_USERNAME_TEST_1 = 'testuser1@sunmotors.com';
    public static final String OWNER_USERNAME_TEST_2 = 'testuser2@sunmotors.com';
    public static final String ZIP_CODE_DEALER_TEST_1 = '91001';
    public static final String ZIP_CODE_DEALER_TEST_2 = '91002';
    
    // Insertion of two users, two territories and one dealer account
    public static void insertTerritoryManagementData()
    {
        insert new User(
            FirstName = 'Test', 
            LastName = 'User 1',
            Email = 'testuser1@gmail.com',
            Username = OWNER_USERNAME_TEST_1,
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
            Username = OWNER_USERNAME_TEST_2,
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
            WHERE Username = :OWNER_USERNAME_TEST_1
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
            WHERE Username = :OWNER_USERNAME_TEST_2
        ].Id;

        insert new Territory__c(
            Name = 'Territory test 2', 
            Zip_Code__c = ZIP_CODE_DEALER_TEST_2, 
            Owner__c = OwnerId2Test
        );

        insert new Account(
            Name = 'Dealer test 1', 
            BillingPostalCode = ZIP_CODE_DEALER_TEST_1, 
            OwnerId = OwnerId1Test
        );
    }
}