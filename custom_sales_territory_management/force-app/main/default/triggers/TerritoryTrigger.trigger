trigger TerritoryTrigger on Territory__c (after update)
{
    AutomobileDealerService dealerService = new AutomobileDealerService();
    List<Account> dealersToUpdate = dealerService.GetAutoDealersWithTerritoryOwnerChanged(
        Trigger.OldMap, 
        Trigger.New
    );

    dealerService.UpdateDataModelOwners(dealersToUpdate);
}