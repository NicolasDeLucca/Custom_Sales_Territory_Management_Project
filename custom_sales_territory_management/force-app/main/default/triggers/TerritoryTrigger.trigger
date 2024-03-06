trigger TerritoryTrigger on Territory__c (after update)
{
    if (Trigger.isAfter && Trigger.isUpdate)
    {
        AutomobileDealerService dealerService = new AutomobileDealerService();
        List<Account> dealersToUpdate = dealerService.GetAutoDealersWithTerritoryOwnerChanged(
            Trigger.OldMap, 
            Trigger.New
        );

        dealerService.UpdateDataModelOwners(dealersToUpdate);
    }
}