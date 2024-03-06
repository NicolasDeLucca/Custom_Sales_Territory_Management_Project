trigger ZipCodeTrigger on Account (after update)
{
    if (Trigger.isAfter && Trigger.isUpdate)
    {
        AutomobileDealerService dealerService = new AutomobileDealerService();
        List<Account> mappedDealers = dealerService.GetAutoDealersWithZipCodeChanged(
            Trigger.OldMap, 
            Trigger.New
        );

        dealerService.ProcessAccountHistory(mappedDealers);
        dealerService.UpdateDataModelOwners(mappedDealers);
    }
}