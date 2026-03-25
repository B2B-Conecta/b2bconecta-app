### Firebase Setup Instructions for IDX

It seems we are having trouble with the interactive login for Firebase. Please follow these steps to authenticate using a service account, which is a more reliable method for this environment.

**Step 1: Create a Service Account and Key**

1.  Open the [Google Cloud Console](https://console.cloud.google.com/) for your Firebase project (`motolink-pro-app`).
2.  In the navigation menu, go to **IAM & Admin > Service Accounts**.
3.  Click **+ CREATE SERVICE ACCOUNT**.
4.  Give the service account a name (e.g., `firebase-idx-admin`).
5.  Grant the service account the **Firebase Admin** role.
6.  Click **Done**.
7.  Find the service account you just created in the list and click on the three dots under "Actions", then select **Manage keys**.
8.  Click **ADD KEY > Create new key**.
9.  Choose **JSON** as the key type and click **CREATE**. A JSON file will be downloaded to your computer.

**Step 2: Upload the Key to IDX**

1.  In the IDX file explorer, right-click on the root of your project directory.
2.  Select **Upload Files...**.
3.  Select the JSON key file you just downloaded.
4.  Rename the uploaded file to `service-account.json`.

**Step 3: Inform the Assistant**

Once you have uploaded the `service-account.json` file, please let me know by typing "I have uploaded the service account key". I will then proceed with the Firebase configuration.
