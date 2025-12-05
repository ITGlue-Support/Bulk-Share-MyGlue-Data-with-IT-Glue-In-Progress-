You can use this script to bulk-share MyGlue data with an IT Glue user. It’s especially useful when performing cross-account migrations, offboarding users, or exporting MyGlue data.

The script scans only the items created in MyGlue and shares them with the IT Glue group that is visible to MyGlue users.

Prerequisites:

1. An Editor-level user who has access to all/majority of shared MyGlue data
2. The ID of the IT Glue group visible to MyGlue users (**Recommended: create a group such as “MyGlue Data”**)
    <img width="707" height="765" alt="image" src="https://github.com/user-attachments/assets/b512df03-9eda-435b-9ac7-6ce0830474f4" />
3. Access to PowerShell ISE to run the script
    <img width="1880" height="184" alt="image" src="https://github.com/user-attachments/assets/2cf03784-cd05-495f-9e55-20451471f183" />

When you run the script, you will be prompted to enter your MyGlue credentials. If you use MFA to log in, provide the MFA code when prompted, or simply press **Enter** to bypass if applicable. Once authentication is successful, the script will begin scanning core assets first, followed by flexible assets.

Due to API limitations for Domains, SSL Certificates, and Flexible Assets, the script will generate a CSV file containing these records. This allows you to identify which items originate from MyGlue even if the script cannot update them directly. Please refer to the example shown below.

<img width="1116" height="527" alt="image" src="https://github.com/user-attachments/assets/642baa0d-96ad-41fb-bb19-806db509625d" />


After the script has finished running, check the **restricted** column in the **MyGlue_record.csv** file to ensure that the value is **true** for all listed records. This confirms that the items have been successfully shared.

If you see any entries marked **false**, review the corresponding data in MyGlue and verify that security permissions are correctly set to specific groups and users, and that they are visible within IT Glue.

**Note:** **This script does **not** update security permissions for MyGlue personal passwords. Users will still need to log in and export personal password data manually**.

**Security update behaviour**

1. If the asset permission is set to All MyGlue user with access to this organization, this script will update the permission to specific users and group and add Editor user used in the script and IT Glue Group
2. If the permission is already set to assign users and groups then script will only add the IT Glue groups without updating the existing groups.

We welcome any recommendations to improve the script. Thank you for your support!


