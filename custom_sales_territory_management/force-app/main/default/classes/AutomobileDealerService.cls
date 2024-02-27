public class AutomobileDealerService
{
    private List<AccountHistory> ZipCodeAccountsHistory { get; private set; }
    private List<Territory__c> Territories { get; private set; }
    private List<Contact> dealersEmployees { get; private set; }
    private List<Opportunity> dealerOpportunities { get; private set; }
    
    private Territory__c GetTerritoryByZipCode(String zipCode)
    {
        List<Territory__c> possibleTerritories = new List<Territory__c>();
        for (Territory__c territory : this.Territories)
        {
            if (territory.Zip_Code__c == zipCode)
                possibleTerritories.add(territory);
        }

        Integer territoriesSize = possibleTerritories.size();
        if (territoriesSize > 0)
        {
            // use a random function to select one of the assigned sales representatives
            Integer randomInt = Math.floor(Math.random()).intValue();
            Integer randomIndex = Math.Mod(randomInt, territoriesSize);
            return possibleTerritories[randomIndex];
        }

        return null;
    }

    // Three sales representatives at most can be assigned to a single zip code.
    private Boolean IsZipCodeAssignable(String zipCode)
    {
        Integer count = 0;
        for (Territory__c territory : this.Territories)
        {
            if (territory.Zip_Code__c == zipCode)
                count++;
        }

        return count <= 3;
    }

    public AutomobileDealerService()
    {
        this.ZipCodeAccountsHistory = 
        [
            SELECT AccountId
            FROM AccountHistory
            WHERE Field = 'BillingPostalCode'
        ];

        this.Territories = 
        [
            SELECT Id, Zip_Code__c, Owner__c
            FROM Territory__c
        ];

        this.dealersEmployees = 
        [
            SELECT Id, AccountId 
            FROM Contact
        ];

        this.dealerOpportunities = 
        [
            SELECT Id, OwnerId
            FROM Opportunity
        ];
    }
    
    // Verifies if some Automobile Dealer's Zip Code has ever changed
    public Boolean HasZipCodeChanged(Id dealerId)
    {
        for (AccountHistory history : this.ZipCodeAccountsHistory)
        {
            if (history.AccountId == dealerId)
                return true;
        }

        return false;
    }

    // Change the Account Owner to the sales representative assigned to the new zip code
    public Account ReassignAccountOwner(Account dealerAccount)
    {
        Territory__c associatedTerritory = this.GetTerritoryByZipCode(dealerAccount.BillingPostalCode);
        Boolean isAssignable = this.IsZipCodeAssignable(dealerAccount.BillingPostalCode);

        if (associatedTerritory != null && isAssignable)
        {
            dealerAccount.OwnerId = associatedTerritory.Owner__c;
            return dealerAccount;
        }
        else if (!isAssignable)
        {
            associatedTerritory.addError('The zip code is already assigned to three sales representatives');
        }

        return null;
    }

    // Change the Owner field of all the Account’s Contacts to the same sales rep
    public List<Contact> ReassignContactsOwner(Account dealerAccount, Id newOwnerId)
    {
        List<Contact> accountEmployees = new List<Contact>();
        for (Contact employee : this.dealersEmployees)
        {
            if (employee.AccountId == dealerAccount.Id)
                accountEmployees.add(employee);
        }

        for (Contact employeesToUpdate : accountEmployees)
        {
            employeesToUpdate.OwnerId = newOwnerId;
        }

        return accountEmployees;
    }

    // Change the Owner field of all the Account’s Open Opportunities to the same sales rep
    public List<Opportunity> ReassignOpenOpportunitiesOwner(Account dealerAccount, Id newOwnerId)
    {
        List<Opportunity> accountOpportunities = new List<Opportunity>();
        for (Opportunity opp : this.dealerOpportunities)
        {
            if (opp.AccountId == dealerAccount.Id && opp.IsClosed == false)
                accountOpportunities.add(opp);
        }

        for (Opportunity opportunitiesToUpdate : accountOpportunities)
        {
            opportunitiesToUpdate.OwnerId = newOwnerId;
        }

        return accountOpportunities;
    }
}