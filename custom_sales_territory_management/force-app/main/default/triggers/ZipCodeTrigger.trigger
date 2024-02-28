trigger ZipCodeTrigger on Account (after update)
{
    AutomobileDealerService dealerService = new AutomobileDealerService();
    List<Account> mappedAccounts = dealerService.GetAccountsWithZipCodeChanged(Trigger.New);
    
    dealerService.UpdateDataModelOwners(mappedAccounts);
}