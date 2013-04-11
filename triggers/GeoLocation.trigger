trigger GeoLocation on Account (after insert, after update) {

	 for (Account A : trigger.new) {
	 	if (trigger.isInsert) {
	 		if (a.BillingGeoCodeData__Latitude__s == null || a.BillingGeoCodeData__Longitude__s == null)
	 			// if records are inserted w/o geocoding data, then geocode them!
	 			GoogleGeoCodeUpdater.GeoCodeSingleAccount(A.ID);
	 	} else if (trigger.isUpdate) {
	 		// Get the old data
	 		Account OldAccountData = Trigger.oldMap.get(A.ID);
	 		// If any fields were changed, geocode the account again!
	 		if ((A.BillingStreet != OldAccountData.BillingStreet) ||
				(A.BillingCity != OldAccountData.BillingCity) ||
	 			(A.BillingState != OldAccountData.BillingState) ||
	 			(A.BillingPostalCode != OldAccountData.BillingPostalCode) ||
	 			(A.ShippingStreet != OldAccountData.ShippingStreet) ||
	 			(A.ShippingCity != OldAccountData.ShippingCity) ||
	 			(A.ShippingState != OldAccountData.ShippingState) ||
	 			(A.ShippingPostalCode != OldAccountData.ShippingPostalCode)
	 			)
	 		{
	 			GoogleGeoCodeUpdater.GeoCodeSingleAccount(A.ID);
	 		} // check for change in billing address
	 	} // if (trigger.isInsert) {
	 } // for (Account A : trigger.new) {
} // GeoLocation