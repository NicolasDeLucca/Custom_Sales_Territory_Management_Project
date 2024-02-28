trigger ZipCodeTrigger on Account (after update)
{
    AutomobileDealerService dealerService = new AutomobileDealerService();
    dealerService.UpdateDataModelOwners(Trigger.New);
}