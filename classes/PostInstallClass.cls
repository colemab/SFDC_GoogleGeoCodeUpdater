global class PostInstallClass implements InstallHandler {
	
	static string JobName = 'DC:GoogleGeoCodeUpdater';
	
	global void onInstall(InstallContext context) {
		
		if(context.previousVersion() != null) {
			UnScheduleJob();
		} // if(context.previousVersion() != null)
		
		this.ScheduleJob();
		
	} // onInstall
	
	private void ScheduleJob() {
		
		GoogleGeoCodeUpdaterSchedule g = new GoogleGeoCodeUpdaterSchedule();
		String sch = '0 0 * * * ?';
		ID CronID = system.schedule(JobName, sch, g);
		
		DC_GG__CronInfo__c CronSettings = new DC_GG__CronInfo__c();
		CronSettings.Name = 'LastRun'; 
		CronSettings.DC_GG__JobID__c = CronID;
		upsert CronSettings;
			
	} // ScheduleJob
	
	private void UnScheduleJob() {
		DC_GG__CronInfo__c CronSettings = DC_GG__CronInfo__c.getInstance('LastRun');
		ID CronID = CronSettings.DC_GG__JobID__c;
		system.abortJob(CronID);
	} // UnScheduleJob
	
	static testMethod Void testInstallScript() {
		
		PostInstallClass postinstall = new PostInstallClass();
    	Test.testInstall(postinstall, null);
    			
	} // testInstallScript
	
} // PostInstallClass