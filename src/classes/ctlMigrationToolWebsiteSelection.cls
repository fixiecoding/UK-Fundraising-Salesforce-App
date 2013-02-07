public with sharing class ctlMigrationToolWebsiteSelection {
    public string strFundRaisingPlatform;
    public List<Fundraiser_Platforms__c> platforms;
    public List<Fundraiser_Platforms__c> getPlatforms() {
        return [SELECT Name_of_Fundraising_Website__c FROM Fundraiser_Platforms__c];
    }
    
    public PageReference GoToDescriptionPage() {
        // Example_Virgin_Money_Giving_Layout
        PageReference redirect = new PageReference('/apex/Example_Virgin_Money_Giving_Layout'); 
        redirect.setRedirect(true); 
        return redirect;    
    }

    public PageReference GoToUploadPage() {
        // VirginMoneyImport
        PageReference redirect = new PageReference('/apex/'+strFundRaisingPlatform); 
        redirect.setRedirect(true); 
        return redirect;  
    }

    public list<SelectOption> options = new list<SelectOption>();

    public string getSelectedItem(){
      return strFundRaisingPlatform;
    }
    public void setSelectedItem(String s){
     this.strFundRaisingPlatform = s;
    }
    
    public list<SelectOption> getItems (){
        String platformName;
        String vfDataUploadPage;
        List<Fundraiser_Platforms__c> platforms;
        platforms = [SELECT Name_of_Fundraising_Website__c, 
                            Name_of_VF_Page_for_Uploading_Data__c 
                            FROM Fundraiser_Platforms__c];
        this.platforms = platforms;
        for (Fundraiser_Platforms__c fp : platforms) {
            platformName = fp.Name_of_Fundraising_Website__c;
            vfDataUploadPage = fp.Name_of_VF_Page_for_Uploading_Data__c;
            options.add(new SelectOption(vfDataUploadPage, platformName));
        }
        return options;
    }
}