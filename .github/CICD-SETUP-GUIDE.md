# 🚀 Salesforce CI/CD Setup Guide

This guide will help you set up the GitHub Actions CI/CD pipeline for your Salesforce project.

---

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Understanding the Pipeline](#understanding-the-pipeline)
3. [Setting Up Salesforce Connected App](#setting-up-salesforce-connected-app)
4. [Configuring GitHub Secrets](#configuring-github-secrets)
5. [Testing the Pipeline](#testing-the-pipeline)
6. [Troubleshooting](#troubleshooting)

---

## 🎯 Prerequisites

Before starting, make sure you have:

- ✅ A GitHub repository with your Salesforce project
- ✅ A Salesforce Sandbox org (for validation)
- ✅ A Salesforce Production org (for deployment) - *Optional initially*
- ✅ Admin access to both your Salesforce org and GitHub repository
- ✅ Basic understanding of Git and Pull Requests

---

## 🔄 Understanding the Pipeline

The pipeline has **3 main steps**:

### Step 1: 📝 Summarize Changes
- **What it does:** Analyzes which Salesforce components were modified
- **When it runs:** Immediately when you create/update a Pull Request
- **Output:** A comment on your PR showing what changed (Apex, LWC, Metadata)

### Step 2: ✅ Validate Deployment
- **What it does:** Tests if your code can be deployed without actually deploying
- **When it runs:** After the summary step
- **Output:** Success/Failure message and test results
- **Purpose:** Catch errors BEFORE merging to main branch

### Step 3: 🚀 Deploy to Salesforce
- **What it does:** Actually deploys your code to Salesforce
- **When it runs:** Only AFTER the PR is merged to main branch
- **Output:** Deployment success/failure notification

---

## 🔐 Setting Up Salesforce Connected App

You need to create a **Connected App** in Salesforce to allow GitHub to authenticate.

### Step-by-Step Instructions:

#### 1. Log into Salesforce
- Go to your Salesforce org (sandbox or production)
- Click the **⚙️ Setup** gear icon (top-right)

#### 2. Create Connected App
1. In Quick Find box, search for **"App Manager"**
2. Click **"New Connected App"** button
3. Fill in the form:

   **Basic Information:**
   - **Connected App Name:** `GitHub Actions CI/CD`
   - **API Name:** `GitHub_Actions_CI_CD` (auto-filled)
   - **Contact Email:** Your email address

   **API (Enable OAuth Settings):**
   - ✅ Check **"Enable OAuth Settings"**
   - **Callback URL:** `http://localhost:1717/OauthRedirect`
   - ✅ Check **"Use digital signatures"**
   - Click **"Choose File"** and upload a certificate (we'll create this next)

   **Selected OAuth Scopes:** Add these scopes:
   - `Access and manage your data (api)`
   - `Perform requests on your behalf at any time (refresh_token, offline_access)`
   - `Access the identity URL service (id)`

4. Click **Save**
5. Click **Continue**

#### 3. Generate Certificate and Private Key

On your computer, open Terminal/Command Prompt and run:

```bash
# Create a private key
openssl genrsa -out server.key 2048

# Create a certificate signing request
openssl req -new -key server.key -out server.csr

# Create a self-signed certificate (valid for 1 year)
openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt
```

**Explanation:**
- `server.key` = Your **private key** (keep this SECRET!)
- `server.crt` = Your **certificate** (upload to Salesforce)

#### 4. Upload Certificate to Salesforce

1. Go back to your Connected App in Salesforce
2. Click **Edit**
3. Under "Use digital signatures", click **Choose File**
4. Upload the `server.crt` file you just created
5. Click **Save**

#### 5. Get Consumer Key

1. In the Connected App details, find **"Consumer Key"**
2. Click **"Click to reveal"** and copy it
3. Save this for later (you'll need it for GitHub secrets)

#### 6. Enable the Connected App

1. Click **Manage**
2. Click **Edit Policies**
3. Under **OAuth Policies:**
   - **Permitted Users:** `Admin approved users are pre-authorized`
4. Click **Save**
5. Click **Manage Profiles** or **Manage Permission Sets**
6. Add your user's profile/permission set

---

## 🔑 Configuring GitHub Secrets

Now you need to add your Salesforce credentials to GitHub as **secrets**.

### Step-by-Step Instructions:

#### 1. Go to GitHub Repository Settings
1. Open your repository on GitHub
2. Click **⚙️ Settings** tab (top-right)
3. In the left sidebar, click **Secrets and variables** → **Actions**

#### 2. Add Repository Secrets

Click **"New repository secret"** for each of the following:

---

### 🔐 Secret 1: `SF_JWT_KEY`

**What it is:** Your private key (from `server.key` file)

**How to add it:**
1. Open `server.key` file in a text editor
2. Copy the ENTIRE content (including `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----`)
3. In GitHub, create new secret:
   - **Name:** `SF_JWT_KEY`
   - **Value:** Paste the entire key content
4. Click **Add secret**

**Example format:**
```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAr1234567890abcdefghijklmnopqrstuvwxyz...
... (many lines of random characters) ...
-----END RSA PRIVATE KEY-----
```

---

### 🔐 Secret 2: `SF_CONSUMER_KEY`

**What it is:** The Consumer Key from your Connected App

**How to add it:**
1. Copy the Consumer Key from Salesforce Connected App
2. In GitHub, create new secret:
   - **Name:** `SF_CONSUMER_KEY`
   - **Value:** Paste the consumer key
3. Click **Add secret**

**Example format:**
```
3MVG9r3qB1234567890.abcdefghijklmnopqrstuvwxyz1234567890ABCDEFG
```

---

### 🔐 Secret 3: `SF_USERNAME`

**What it is:** The Salesforce username for authentication

**How to add it:**
1. In GitHub, create new secret:
   - **Name:** `SF_USERNAME`
   - **Value:** Your Salesforce username (usually an email)
3. Click **Add secret**

**Example format:**
```
admin@yourcompany.com.sandbox
```

**Note:** For sandbox orgs, username often ends with `.sandbox` or `.dev`

---

### 🔐 Secret 4: `SF_INSTANCE_URL`

**What it is:** Your Salesforce org URL

**How to add it:**
1. In GitHub, create new secret:
   - **Name:** `SF_INSTANCE_URL`
   - **Value:** Your Salesforce org URL
3. Click **Add secret**

**Example values:**
- Sandbox: `https://test.salesforce.com`
- Production: `https://login.salesforce.com`
- Custom domain: `https://yourcompany.my.salesforce.com`

---

### 🎯 Optional: Production Secrets (for deployment)

If you want different credentials for validation vs. production deployment, add these:

- `SF_PROD_CONSUMER_KEY` - Production org consumer key
- `SF_PROD_USERNAME` - Production org username
- `SF_PROD_INSTANCE_URL` - Production org URL

**If you don't add these, the pipeline will use the same credentials for both validation and deployment.**

---

## ✅ Verify Your Secrets

After adding all secrets, you should see:

✅ `SF_JWT_KEY`
✅ `SF_CONSUMER_KEY`
✅ `SF_USERNAME`
✅ `SF_INSTANCE_URL`

(Optional)
⚪ `SF_PROD_CONSUMER_KEY`
⚪ `SF_PROD_USERNAME`
⚪ `SF_PROD_INSTANCE_URL`

---

## 🧪 Testing the Pipeline

Now let's test if everything works!

### Test 1: Create a Test Pull Request

1. **Create a new branch:**
   ```bash
   git checkout -b test-cicd
   ```

2. **Make a small change** (e.g., add a comment to an Apex class):
   ```bash
   # Edit a file in force-app/
   echo "// Test comment" >> force-app/main/default/classes/YourClass.cls
   ```

3. **Commit and push:**
   ```bash
   git add .
   git commit -m "test: CI/CD pipeline"
   git push origin test-cicd
   ```

4. **Create Pull Request on GitHub:**
   - Go to your repository
   - Click **"Pull requests"** tab
   - Click **"New pull request"**
   - Select your `test-cicd` branch
   - Click **"Create pull request"**

5. **Watch the pipeline run:**
   - Go to **"Actions"** tab
   - You should see the workflow running
   - Check for the comment on your PR with the summary

### Test 2: Check Validation

- Wait for the validation step to complete
- Check the PR comments for validation results
- If it fails, check the logs in the Actions tab

### Test 3: Test Deployment (Optional)

- If validation passes, merge the PR
- Watch the deployment step run in Actions tab
- Check Salesforce org to verify deployment

---

## 🐛 Troubleshooting

### Problem: "Invalid JWT" or "Authentication Failed"

**Possible causes:**
- Private key doesn't match certificate
- Certificate not uploaded to Connected App
- Consumer Key is incorrect
- Username is wrong

**Solution:**
1. Verify `SF_JWT_KEY` secret contains the complete private key
2. Re-check Consumer Key in Salesforce matches `SF_CONSUMER_KEY`
3. Verify username format (include `.sandbox` for sandboxes)
4. Make sure Connected App is enabled and your user has access

---

### Problem: "Org not found" or "Instance URL invalid"

**Possible causes:**
- Wrong instance URL
- Org is inactive or deleted

**Solution:**
1. Check `SF_INSTANCE_URL` - should be `https://test.salesforce.com` or `https://login.salesforce.com`
2. Try logging into Salesforce manually with the same URL
3. If using My Domain, use the full URL: `https://yourcompany.my.salesforce.com`

---

### Problem: "Validation failed with errors"

**Possible causes:**
- Test failures in your Salesforce code
- Missing dependencies
- Code coverage too low

**Solution:**
1. Check the validation logs in GitHub Actions
2. Look for specific error messages
3. Fix the errors in your code
4. Run tests locally: `sf apex test run --target-org yourOrg`

---

### Problem: Workflow doesn't run

**Possible causes:**
- Workflow file has syntax errors
- No changes in `force-app/` directory
- Branch doesn't have the workflow file

**Solution:**
1. Check workflow file syntax at: https://yamlchecker.com/
2. Make sure you're changing files in `force-app/`
3. Verify `.github/workflows/salesforce-ci-cd.yml` exists in your branch
4. Check Actions tab → Look for error messages

---

### Problem: "Deployment successful but changes not visible"

**Possible causes:**
- Deployed to wrong org
- Need to refresh browser
- Changes cached

**Solution:**
1. Verify you're checking the correct Salesforce org
2. Hard refresh browser (Ctrl+F5 or Cmd+Shift+R)
3. Check deployment log for deployed components
4. Verify org with: `sf org display --target-org production-org`

---

## 📚 Additional Resources

- **Salesforce DX Setup Guide:** https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/
- **GitHub Actions Documentation:** https://docs.github.com/en/actions
- **JWT Auth Flow:** https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_auth_jwt_flow.htm
- **Salesforce CLI Commands:** https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/

---

## 💡 Tips for Beginners

1. **Start with Sandbox:** Always test with a sandbox org first, never production
2. **Small Changes:** Make small, incremental changes to test the pipeline
3. **Read Logs:** GitHub Actions logs are very detailed - read them carefully
4. **Ask for Help:** If stuck, share the error logs when asking for help
5. **Security:** Never commit `server.key` file to Git - keep it secret!

---

## 🎉 You're Done!

Your CI/CD pipeline is now set up! Every time you create a Pull Request:

1. ✅ Changes will be summarized
2. ✅ Code will be validated against Salesforce
3. ✅ After merge, code will be deployed automatically

Happy coding! 🚀
