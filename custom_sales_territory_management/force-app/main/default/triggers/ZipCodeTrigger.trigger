trigger ZipCodeTrigger on Account (after update)
{
    AutomobileDealerService dealerService = new AutomobileDealerService();
    
    List<Contact> contactsToUpdate = new List<Contact>();
    List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
    List<Account> accountsToUpdate = new List<Account>();

    for (Account updatedAcc : Trigger.New)
    {
        if (!dealerService.HasZipCodeChanged(updatedAcc.Id))
        {
            Account accountToUpdate = dealerService.ReassignAccountOwner(updatedAcc);
            if (accountToUpdate != null)
            {
                List<Contact> newContactsToUpdate = 
                    dealerService.ReassignContactsOwner(updatedAcc, accountToUpdate.OwnerId);
                
                List<Opportunity> newOppsToUpdate = 
                    dealerService.ReassignOpenOpportunitiesOwner(updatedAcc, accountToUpdate.OwnerId);
                
                contactsToUpdate.addAll(newContactsToUpdate);
                opportunitiesToUpdate.addAll(newOppsToUpdate);
                accountsToUpdate.add(accountToUpdate);
            }
        }
    }

    if (!contactsToUpdate.isEmpty())
    {
        update contactsToUpdate;
    }

    if (!accountsToUpdate.isEmpty())
    {
        update accountsToUpdate;
    }

    if (!opportunitiesToUpdate.isEmpty())
    {
        update opportunitiesToUpdate;
    }
}