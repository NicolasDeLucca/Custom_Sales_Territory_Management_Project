public class AutomobileDealerRepairment implements Schedulable
{
    private void EnsureAutomobileDealersIntegrity()
    {
        List<Account> dealersToUpdate = new List<Account>();

        List<Territory__c> territories = 
        [
            SELECT Owner__c, Zip_Code__c
            FROM Territory__c
        ];

        List<Account> automobileDealers = 
        [
            SELECT OwnerId, BillingPostalCode
            FROM Account
        ];

        for (Account dealer : automobileDealers)
        {
            Boolean isDealerInAnyTerritory = false;
            for (Territory__c territory : territories)
            {
                if (territory.Zip_Code__c == dealer.BillingPostalCode && dealer.OwnerId == territory.Owner__c)
                {
                    isDealerInAnyTerritory = true;
                    break;
                }
            }
            if (!isDealerInAnyTerritory)
                dealersToUpdate.add(dealer);
        }

        AutomobileDealerService dealerService = new AutomobileDealerService();
        dealerService.UpdateDataModelOwners(dealersToUpdate);
    }
    
    public void execute(SchedulableContext context)
    {
        this.EnsureAutomobileDealersIntegrity();
    }
}