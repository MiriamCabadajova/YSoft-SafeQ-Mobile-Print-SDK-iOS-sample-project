# YSoft SafeQ Mobile Print SDK iOS
This repository intends to deliver the mobile SDK within a sample mobile application, developed for the YSoft Corporation a.s., for accessing the functionality of SafeQ product.

The main functionality included in the SDK is the login and upload to the YSoft SafeQ using two main channels - End User Interface and the Mobile Integration Gateway.

The mobile SDK is supplied in the *YSoft SafeQ SDK* folder. It includes *Delivery.swift*, *Login.swift* and *Upload.swift* classes comprising the core functionality of SDK and *Printjob.swift* struct representing the print jobs to be uploaded to the YSoft SafeQ. Also, the *DeliveryEndpoint.swift* enum is present in the SDK. Their integration into the code is shown in the *LoginViewController.swift* and *UploadViewController.swift* classes. The application contains only basic UI elements as they will be chosen and modified by software engineers developing the mobile application with their custom assets. 

For more detailed instructions on how to integrate the mobile SDK into your iOS application and utilize its functionality, see the bachelor's thesis... 

## User Experience
The minimal required version of iOS is 12.2.

You can launch the application by clicking the file with *.xcodeproj* suffix. 

The application presents a login screen with input textfields:
 * The server textfield is filled by the address of the desired endpoint:
    * The discovery button discovers local printers, and, if the textfield is filled by the domain (e.g. ysoft.local), the rest of the URL is discovered by the application.  
    * Otherwise, one of the URLs can be entered:
      * EUI/MPS: https://server-with-eui:9443/end-user/ui/,
      * MIG: https://server-with-mig:8050.
 * The username and password textfields are filled by the YSoft SafeQ credentials.
 
After the successful login, the upload screen is presented. At the top, the *Add file* button adds an empty generic *test.txt* file to the table view. After adding file(s) to the tableview, the upload may be initiated after clicking the *Upload* button. If the upload of the files succeeds, they may be displayed in the end user interface at https://server-with-eui/end-user/ui/. These print jobs may be released by authenticating at any printer with SafeQ installed.

## Developer Experience
For detailed information on the development with the mobile SDK see the *YSoft SafeQ SDK* folder.




