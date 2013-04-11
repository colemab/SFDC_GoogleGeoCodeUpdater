public with sharing class GoogleGeoCodeUpdater { 
    
    public enum AccountGeocodingMode {BILLING, SHIPPING}
    
    public static AccountGeocodingMode CurrentAccountGeocodingMode;
    	  
    public static List <Account> AccountsToGeoCode = new List <Account>();
 
 	// When you specify future, the method executes when Salesforce has available resources.
    @future(callout=true)
    public static void ProcessUpdates(){
        // This method is to be called from the scheduled class and will process the account list
        if (PopulateAccountList() == true ) {
            
            system.debug('AccountsToGeoCode.size() = ' + AccountsToGeoCode.size());
            
            for(integer i=0; i<AccountsToGeoCode.size(); i++) {
                 
                GeocodeAccountAddress(AccountsToGeoCode[i]);
                 
            } // loop thru accounts list
             
            // Update all changed records in one DML statement
            update AccountsToGeoCode;
             
        } // check for PopulateAccountList = true
         
    } // ProcessUpdates

	@future(callout=true)
	public static void GeoCodeSingleAccount(Id AccountID) {
		// This is a wrapper method that is to be called from the trigger
		// Note that currently you can't pass sobjects into async methods, thus the ID being passed instead
		Account A = [
				SELECT BillingCity, BillingPostalCode, BillingState, BillingStreet, ShippingCity, ShippingPostalCode, ShippingState, ShippingStreet
				FROM Account 
				WHERE id = :AccountID
				];
		
		system.debug('GeoCodeSingleAccount: AccountID = ' + AccountID);
		
		CurrentAccountGeocodingMode = AccountGeocodingMode.SHIPPING;
		GeocodeAccountAddress(A);
		
		CurrentAccountGeocodingMode = AccountGeocodingMode.BILLING;
		GeocodeAccountAddress(A);
		
		update A;
		
	} // GeoCodeSingleAccount
     
    private static string BuildAddressString(String Street, String City, String State, String PostalCode) {
    	String Address = '';

        if(Street != null) {
            Address = EncodingUtil.urlEncode(Street,'UTF-8')+ ',+';
        } // Street != null
        if(City != null && State != null) {
            Address = Address + EncodingUtil.urlEncode(City,'UTF-8')+ ',+' +
                      EncodingUtil.urlEncode(State,'UTF-8');
        } // City != null &&  State != null
        if(PostalCode != null) {
            Address = Address  + ',+' + EncodingUtil.urlEncode(PostalCode,'UTF-8');
        } // zip ! = null
    	
    	return Address;
    	
    } // BuildAddressString 
    
    private static string BuildBillingAddressString(Account AccountToBuildAddress) {
        	Return BuildAddressString(AccountToBuildAddress.BillingStreet,AccountToBuildAddress.BillingCity,AccountToBuildAddress.BillingState,AccountToBuildAddress.BillingPostalCode);         
    } // BuildBillingAddressString

    private static string BuildShippingAddressString(Account AccountToBuildAddress) {
        	Return BuildAddressString(AccountToBuildAddress.ShippingStreet,AccountToBuildAddress.ShippingCity,AccountToBuildAddress.ShippingState,AccountToBuildAddress.ShippingPostalCode);         
    } // BuildShippingAddressString
     
    private static void GeocodeAccountAddress(Account AccountToGeoCode) {
          
		String GeoCodeRequestURL = '';
		String AddressRequestURL = '';
        
        if (CurrentAccountGeocodingMode == AccountGeocodingMode.BILLING) {
        	AddressRequestURL = BuildBillingAddressString(AccountToGeoCode);
        } else if( CurrentAccountGeocodingMode == AccountGeocodingMode.SHIPPING) {
        	AddressRequestURL = BuildShippingAddressString(AccountToGeoCode);
        } // CurrentAccountGeocodingMode = AccountGeocodingMode.SHIPPING;
        
         
		if (AddressRequestURL != '') {
			GeoCodePoint CurrentGeoCodeResult = new GeoCodePoint();
	          
			HttpRequest GeoCodeRequest = new HttpRequest();
	        Http GeoCodeHttp = new Http();
	           
	        GeoCodeRequest.setMethod('GET');
	           
	        GeoCodeRequestURL = 'http://maps.googleapis.com/maps/api/geocode/json?address='+ AddressRequestURL + '&sensor=false';	          
			system.debug('Request URL was: ' + GeoCodeRequestURL);
   
			GeoCodeRequest.setEndpoint(GeoCodeRequestURL);
   
			HttpResponse GeoCodeResponse = GeoCodeHttp.send(GeoCodeRequest);
			CurrentGeoCodeResult = ParseGeoCodeJSONReponse(GeoCodeResponse.getBody()); 
	     
    		system.debug('Setting Longitude: ' + CurrentGeoCodeResult.Longitude);
    		system.debug('Setting Latitude: ' + CurrentGeoCodeResult.Latitude);
			
			if (CurrentAccountGeocodingMode == AccountGeocodingMode.BILLING) {
				AccountToGeocode.BillingGeoCodeData__Latitude__s = CurrentGeoCodeResult.Latitude;
        		AccountToGeocode.BillingGeoCodeData__Longitude__s = CurrentGeoCodeResult.Longitude;
        		AccountToGeoCode.BillingLastGeocoded__c = System.Now();
			} else if( CurrentAccountGeocodingMode == AccountGeocodingMode.SHIPPING) {
				AccountToGeocode.ShippingGeoCodeData__Latitude__s = CurrentGeoCodeResult.Latitude;
        		AccountToGeocode.ShippingGeoCodeData__Longitude__s = CurrentGeoCodeResult.Longitude;
        		AccountToGeoCode.ShippingLastGeocoded__c = System.Now();					
			} // CurrentAccountGeocodingMode = AccountGeocodingMode.SHIPPING;
          
     	} // if (AddressRequestURL != '') {   

 	} // GeocodeAddress
     
    private static GeoCodePoint ParseGeoCodeJSONReponse(String ResponseBody) {
 
         GeoCodePoint ReturnGeoCodeResult = new GeoCodePoint();
          
         JSONParser parser = JSON.createParser(ResponseBody);
         
         system.debug('ResponseBody = ' + ResponseBody);
          
         while (parser.nextToken() != null) {
                                                                             
                        if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&
                            (parser.getText() == 'location')) {
                             
                            ReturnGeoCodeResult = new GeoCodePoint();
							
							while (parser.nextToken() != JSONToken.END_OBJECT){
								String CurrentTextValue = parser.getText();
								parser.nextToken();	
								
								if (CurrentTextValue == 'lng') {
		                            ReturnGeoCodeResult.Longitude = parser.getDoubleValue();
		                            system.debug('Found Longitude: ' + ReturnGeoCodeResult.Longitude);									
								} else if (CurrentTextValue == 'lat') {
		                            ReturnGeoCodeResult.Latitude = parser.getDoubleValue();                          
		                            system.debug('Found Latitude: ' + ReturnGeoCodeResult.Latitude);									
								} // search for long / lat markers
							} // while (parser.nextToken() != JSONToken.END_OBJECT){
                             
                        } // if point    
                                     
            } // while (parser.nextToken() != null)
         
        return ReturnGeoCodeResult;
          
    } // GeoCodeResult
     
 
 	private static boolean PopulateAccountList() {
 		boolean returnValue = false;
 		
 		if (PopulateAccountListWithBilling() == false) {
 			returnValue = PopulateAccountListWithShipping();
 			// set the current mode to shipping w/o checking the return value
 			// because if the list is blank, no processing will occur anyway
 			CurrentAccountGeocodingMode = AccountGeocodingMode.SHIPPING;
 		} else {
 			CurrentAccountGeocodingMode = AccountGeocodingMode.BILLING;
 			returnValue = true;
 		}
 	
 		return returnValue;
 			
 	} // PopulateAccountsList
 
 	private static boolean PopulateAccountListWithBilling() {

        boolean success = false;
         
        // first we look for accounts that haven't been geocoded
        // 2500 is the max daily limit we can process on the free google service
        // but 10 is the max number of call outs per execute on SFDC as of 3/22/12
         
  		// Notice how entries without city state combinations or postal codes are filtered up front for faster processing
   
   		// look for accounts that haven't had billing addresses geocoded
  		AccountsToGeoCode =
            [
                SELECT Id, BillingState, BillingCity, BillingStreet, BillingPostalCode,
                       LastModifiedDate, BillingLastGeocoded__c, BillingNeedsGeocodeUpdated__c
                FROM Account
                WHERE BillingLastGeocoded__c = null AND (
                    (BillingCity != null AND BillingState != null) OR (BillingPostalCode!=null)
                    )
                LIMIT 10
            ];
 
 	
        if (AccountsToGeoCode.size()==0) {
 
            // Next look for billing address geocodes that are out of date         
            AccountsToGeoCode =
                [
                    SELECT Id, BillingState, BillingCity, BillingStreet, BillingPostalCode,
                    LastModifiedDate, BillingLastGeocoded__c, BillingNeedsGeocodeUpdated__c
                    FROM Account
                    WHERE BillingNeedsGeocodeUpdated__c = 'True'
                    LIMIT 10
                ];
        } // check for size = 0 - for billing addresses that are out of date   
                
        if (AccountsToGeoCode.size()>0) {
            success = true;
        } // check for size > 0
        
        system.debug('PopulateAccountList = ' + success);
         
        return success;
 		
 	} // PopulateAccountsListWithBilling
 	
    private static boolean PopulateAccountListWithShipping() {
         
        boolean success = false;
         
        // first we look for accounts that haven't been geocoded
        // 2500 is the max daily limit we can process on the free google service
        // but 10 is the max number of call outs per execute on SFDC as of 3/22/12
         
  		// Notice how entries without city state combinations or postal codes are filtered up front for faster processing
           	
  		AccountsToGeoCode =
            [
                SELECT Id, ShippingState, ShippingCity, ShippingStreet, ShippingPostalCode,
                       LastModifiedDate, ShippingLastGeocoded__c, ShippingNeedsGeocodeUpdated__c
                FROM Account
                WHERE ShippingLastGeocoded__c = null AND (
                    (ShippingCity != null AND ShippingState != null) OR (ShippingPostalCode!=null)
                    )
                LIMIT 10
            ];        	
    	
        if (AccountsToGeoCode.size()==0) {
 
            // Next look for shipping address geocodes that are out of date         
            AccountsToGeoCode =
                [
                    SELECT Id, ShippingState, ShippingCity, ShippingStreet, ShippingPostalCode,
                    LastModifiedDate, ShippingLastGeocoded__c, ShippingNeedsGeocodeUpdated__c
                    FROM Account
                    WHERE ShippingNeedsGeocodeUpdated__c = 'True'
                    LIMIT 10
                ];
        } // check for size = 0 - for shipping addresses that are out of date   
                
        if (AccountsToGeoCode.size()>0) {
            success = true;
        } // check for size > 0
        
        system.debug('PopulateAccountList = ' + success);
         
        return success;
         
    } // PopulateAccountListWithShipping
     
    public class GeoCodePoint {
        double Longitude {get;set;}
        double Latitude {get;set;}
    } // GeoCodePoint class
     
    static testMethod void TestGoogleGeoCodeUpdater() {
        
        // Use the Mock HTTP callout response that was added in winter 13
        Test.setMock(HttpCalloutMock.class, new GoogleGeoCodeMock());
        
    	test.startTest();
        
        // look for geocodes that are out of date
        GoogleGeoCodeUpdater.ProcessUpdates();
        
        // create an account w/o zip
        Account MyAccount = new Account(Name='Test GeoCode Account 1');
        MyAccount.BillingStreet = '251 South Donahue Drive';
        MyAccount.BillingCity = 'Auburn';
        MyAccount.BillingState = 'AL';
        insert MyAccount;  

		// create an account with a zip
        Account MyAccount2 = new Account(Name='Test GeoCode Account 2');
        MyAccount2.BillingStreet = '1701 Valley View Dr';
        MyAccount2.BillingCity = 'Birmingham';
        MyAccount2.BillingState = 'AL';
        MyAccount2.BillingPostalCode = '35209';
        insert MyAccount2;  

        // Run the single Account wrapper method
        GoogleGeoCodeUpdater.GeoCodeSingleAccount(MyAccount2.ID);
         
        // run the normal updates . . . 
        GoogleGeoCodeUpdater.ProcessUpdates();
                
        // return a bad result
        Account MyAccount3 = new Account(Name='Test GeoCode Account 3');
        MyAccount3.BillingStreet = 'REJECT=TEST';
        MyAccount3.BillingCity = '';
        MyAccount3.BillingState = 'AL';
        MyAccount3.BillingPostalCode = '';
        insert MyAccount3;

        // Just in case the trigger doesn't exist, call the update directly to cause a failure
        GoogleGeoCodeUpdater.GeoCodeSingleAccount(MyAccount3.ID);

		// issue an update to increase code coverage in the trigger        
        MyAccount3.BillingState = 'MS';
        upsert MyAccount3;
        
        
        test.stopTest();                
    } // TestGoogleGeoCodeUpdater
     
} // end GoogleGeoCodeUpdater class