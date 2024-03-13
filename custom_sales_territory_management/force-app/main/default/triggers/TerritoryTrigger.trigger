trigger TerritoryTrigger on Territory__c (before insert, before update, after update)
{
    AutomobileDealerService dealerService = new AutomobileDealerService();
    
    if (Trigger.isAfter && Trigger.isUpdate)
    {
        List<Account> dealersToUpdate = dealerService.GetAutoDealersWithTerritoryOwnerChanged(
            Trigger.OldMap, 
            Trigger.New
        );

        dealerService.UpdateDataModelOwners(dealersToUpdate);
    }
    else if (Trigger.isBefore)
    {
        dealerService.ProcessTerritoryUpsertion(Trigger.New);
    }
}