global class GoogleGeoCodeMock implements HttpCalloutMock {

	global HTTPResponse respond(HTTPRequest req) {
		
		String GeoCodeResponse = '';
		System.Httpresponse ReturnValue = new System.Httpresponse();
		
		system.debug('Request = ' + req.getEndpoint());
		
		if (req.getEndpoint().contains('REJECT%3DTEST') == false) {
			// use a hard coded response for now
			GeoCodeResponse = '{ "results" : [ { "address_components" : [ { "long_name" : "525","short_name" : "525","types" : [ "street_number" ]},{"long_name" : "South Lexington Avenue","short_name" : "S Lexington Ave","types" : [ "route" ]},{"long_name" : "Burlington","short_name" : "Burlington","types" : [ "locality", "political" ]},{"long_name" : "12, Burlington","short_name" : "12, Burlington","types" : [ "administrative_area_level_3", "political" ]},{"long_name" : "Alamance","short_name" : "Alamance","types" : [ "administrative_area_level_2", "political" ]},{"long_name" : "North Carolina","short_name" : "NC","types" : [ "administrative_area_level_1", "political" ]},{"long_name" : "United States","short_name" : "US","types" : [ "country", "political" ]},{"long_name" : "27215","short_name" : "27215","types" : [ "postal_code" ]}],"formatted_address" : "525 South Lexington Avenue, Burlington, NC 27215, USA","geometry" : {"bounds" : {"northeast" : {"lat" : 36.09054350,"lng" : -79.43731910},"southwest" : {"lat" : 36.09053150,"lng" : -79.437330}},"location" : {"lat" : 36.09054350,"lng" : -79.437330},"location_type" : "RANGE_INTERPOLATED","viewport" : {"northeast" : {"lat" : 36.09188648029149,"lng" : -79.43597556970850},"southwest" : {"lat" : 36.08918851970849,"lng" : -79.43867353029152}}},"types" : [ "street_address" ]}],"status" : "OK"}';
		} // check for failure code
		
		// but set the return via the variable to allow for future development
		ReturnValue.setBody(GeoCodeResponse);
		
		return ReturnValue;
		
	} // HTTPResponse
	
} // GoogleGeoCodeMock