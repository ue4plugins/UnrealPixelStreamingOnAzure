These files are for customers looking to deploy their Unreal Pixel Streaming solution
with the Azure Marketplace, which require customizations to the Matchmaker
and Signalling Web Server files. The directions below show how to start from the Azure
base first and add your customizations on top of those so the deployment works.

NOTE:
If you HAVE NOT made any changes to those files from the exported package from Unreal, 
ignore these steps and don't select the checkbox in the Azure Marketplace that specifies
you have made custom changes, which will allow Microsoft to override the changes for you 
from your uploaded zip file.

Steps To Add Customizations

1) Export your Pixel Streaming project from Unreal Engine.
2) In the exported content, create a folder at this path: Engine\Source\Programs\PixelStreaming\WebServers.
3) In the exported content, you can optionally delete the Samples folder.
4) Take the "Matchmaker" and "SignallingWebServer" folders in this downloaded zip file and copy into the 
   folder created in step 2 (adds Azure customizations like ports, scripts, etc..).
5) Now you can make any additional changes to the Matchmaker and Signalling Web Server files, such
   as the player.html, CSS, images, etc., while not removing or altering the Azure specific batch
   and PowerShell files. Be careful when changing any NodeJS JavaScript files, and test locally and
   in Azure on a single VM to validate web servers still run as expected before uploading to Blob storage
   in your Azure Storage account. Steps for testing locally are found on the Pixel Streaming documentation
   here: https://docs.unrealengine.com/4.27/en-US/SharingAndReleasing/PixelStreaming/PixelStreamingIntro.
6) Go to the folder (not in the folder) that was exported by Unreal Engine (i.e., WindowsNoEditor) and
   right click on that folder and zip up the contents of that folder and upload that to Blob storage. 
   The zip file should contain the 1) <UE4 App name>.exe,  2) <UE4 App name> folder 
   and 3) Engine folder which has the Azure base changes and your customizations on top of that.