public with sharing class GoogleGeoCodeUpdater { 
 
 // used to build address to geocode (from database fields in SFDC)
    public string Address {get;set;}
    public string City {get;set;}
    public string State {get;set;}
    public string Zip {get;set;}
 
    public static List <Account> AccountsToGeoCode = new List <Account>();
 
 // When you specify future, the method executes when Salesforce has available resources.
    @future(callout=true)
    public static void ProcessUpdates(){
         
        if (PopulateAccountList() == true ) {
             
            for(integer i=0; i<AccountsToGeoCode.size(); i++) {
                 
                GeocodeAccountAddress(AccountsToGeoCode[i]);
                 
            } // loop thru accounts list
             
            // Update all changed records in one DML statement
            update AccountsToGeoCode;
             
        } // check for PopulateAccountList = true
         
    } // ProcessUpdates
     
    private static string BuildAddressString(Account AccountToBuildAddress) {
        String Address = '';
         
  // urlEncode = obtain the bytes for unsafe characters
   
        if (AccountToBuildAddress != null) {
            if(AccountToBuildAddress.BillingStreet != null) {
                Address = EncodingUtil.urlEncode(AccountToBuildAddress.BillingStreet,'UTF-8')+ ',+';
            } // Street != null
            if(AccountToBuildAddress.BillingCity != null && AccountToBuildAddress.BillingState != null) {
                Address = Address + EncodingUtil.urlEncode(AccountToBuildAddress.BillingCity,'UTF-8')+ ',+' +
                          EncodingUtil.urlEncode(AccountToBuildAddress.BillingState,'UTF-8');
            } // City != null &&  State != null
            if(AccountToBuildAddress.BillingPostalCode != null) {
                Address = Address  + ',+' + EncodingUtil.urlEncode(AccountToBuildAddress.BillingPostalCode,'UTF-8');
            } // zip ! = null
        } // AccountToBuildAddress != null
         
        Return Address;
         
    } // BuildAddressString
     
    private static void GeocodeAccountAddress(Account AccountToGeoCode) {
          
         String GeoCodeRequestURL = '';
         GeoCodePoint CurrentGeoCodeResult = new GeoCodePoint();
          
          HttpRequest GeoCodeRequest = new HttpRequest();
          Http GeoCodeHttp = new Http();
           
          GeoCodeRequest.setMethod('GET');
           
          GeoCodeRequestURL = 'http://maps.google.com/maps/geo?q='+ BuildAddressString(AccountToGeoCode)
                                + '&output=json&sensor=false';
           
          GeoCodeRequest.setEndpoint(GeoCodeRequestURL);
           
    // no HTTP call outs from test methods ...
          if (test.IsRunningTest() == false) {
           
             HttpResponse GeoCodeResponse = GeoCodeHttp.send(GeoCodeRequest);
             CurrentGeoCodeResult = ParseGeoCodeJSONReponse(GeoCodeResponse.getBody()); 
     
          } else {
     
             String GeoCodeResponse = '{"Point": { "coordinates": [ -86.8142376, 33.5195411, 0 ] } } ';
             CurrentGeoCodeResult = ParseGeoCodeJSONReponse(GeoCodeResponse);           
     
          } // Istest == false   
           
           
          if (CurrentGeoCodeResult != null) {
              if (CurrentGeoCodeResult.Latitude != '' && CurrentGeoCodeResult.Longitude != '') {
                 AccountToGeoCode.BillingLat__c = CurrentGeoCodeResult.Latitude;
                 AccountToGeoCode.BillingLong__c = CurrentGeoCodeResult.Longitude;
                 AccountToGeoCode.GeocodeLastUpdated__c = System.Now();
              } // check for null coords
          } else {
             system.debug('CurrentGeoCodeResult was null! Skipping this address due to bad JSON parse or response!');
          }      
           
          // update the date even if it failed to prevent reupdating and looping over bad records during inital caching
    // and to give new records priority over reruns
          AccountToGeoCode.GeocodeLastUpdated__c = System.Now();
 
 } // GeocodeAddress
     
    private static GeoCodePoint ParseGeoCodeJSONReponse(String ResponseBody) {
 
         GeoCodePoint ReturnGeoCodeResult = null;
          
         JSONParser parser = JSON.createParser(ResponseBody);
          
         while (parser.nextToken() != null) {
                                                                             
                        if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&
                            (parser.getText() == 'coordinates')) {
                             
                            ReturnGeoCodeResult = new GeoCodePoint();
                                                     
                            parser.nextToken();
                                                         
                            parser.nextToken();
                            ReturnGeoCodeResult.Longitude = parser.getText();
                            system.debug('Longitude: ' + ReturnGeoCodeResult.Longitude);
                             
                            parser.nextToken();                                                    
                            ReturnGeoCodeResult.Latitude =  parser.getText();                          
                            system.debug('Latitude: ' + ReturnGeoCodeResult.Latitude);
                             
                            return ReturnGeoCodeResult;
                        } // if point    
             
            } // while (parser.nextToken() != null)
         
        return ReturnGeoCodeResult;
          
    } // GeoCodeResult
     
 
    private static boolean PopulateAccountList() {
         
        boolean success = false;
         
        // first we look for accounts that haven't been geocoded
        // 2500 is the max daily limit we can process on the free google service
        // but 10 is the max number of call outs per execute on SFDC as of 3/22/12
         
  // Notice how entries without city state combinations or postal codes are filtered up front for faster processing
   
  AccountsToGeoCode =
            [
                SELECT Id, BillingState, BillingCity, BillingStreet, BillingPostalCode,
                       BillingLat__c, BillingLong__c, LastModifiedDate, GeocodeLastUpdated__c, GeocodeNeedsUpdated__c
                FROM Account
                WHERE GeocodeLastUpdated__c = null AND (
                    (BillingCity != null AND BillingState != null) OR (BillingPostalCode!=null)
                    )
                LIMIT 10
            ];
 
 
        if (AccountsToGeoCode.size()==0) {
 
            // Next look for geocodes that are out of date         
            AccountsToGeoCode =
                [
                    SELECT Id, BillingState, BillingCity, BillingStreet, BillingPostalCode,
                    BillingLat__c, BillingLong__c, LastModifiedDate, GeocodeLastUpdated__c, GeocodeNeedsUpdated__c
                    FROM Account
                    WHERE GeocodeNeedsUpdated__c = 'True'
                    LIMIT 10
                ];
        } // check for size = 0                
         
        if (AccountsToGeoCode.size()>0) {
            success = true;
        } // check for size > 0
         
        return success;
         
    } // PopulateAccountList
     
    public class GeoCodePoint {
        String Longitude {get;set;}
        String Latitude {get;set;}
    } // GeoCodePoint class
     
    static testMethod void TestGoogleGeoCodeUpdater() {
        // create an account
        Account MyAccount = new Account(Name='Test GeoCode Account');
        MyAccount.BillingStreet = '251 South Donahue Drive';
        MyAccount.BillingCity = 'Auburn';
        MyAccount.BillingState = 'AL';
        insert MyAccount;  
         
        GoogleGeoCodeUpdater.ProcessUpdates();
    }
     
} // end GoogleGeoCodeUpdater class