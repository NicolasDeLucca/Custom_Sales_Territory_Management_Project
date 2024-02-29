trigger ZipCodeTrigger on Account (after update)
{
    AutomobileDealerService dealerService = new AutomobileDealerService();
    List<Account> mappedDealers = dealerService.GetAutoDealersWithZipCodeChanged(Trigger.New);
    
    dealerService.UpdateDataModelOwners(mappedDealers);
}