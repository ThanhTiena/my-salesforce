# 🔄 CI/CD Pipeline Flow Diagram

## Visual Flow of the Pipeline

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DEVELOPER WORKFLOW                                │
└─────────────────────────────────────────────────────────────────────┘

1️⃣ Developer creates a branch
   └─> git checkout -b feature/new-feature

2️⃣ Developer makes changes to Salesforce code
   └─> Edit Apex classes, LWC, metadata in force-app/

3️⃣ Developer commits and pushes
   └─> git add .
   └─> git commit -m "feat: add new feature"
   └─> git push origin feature/new-feature

4️⃣ Developer creates Pull Request on GitHub
   └─> GitHub UI: Create Pull Request

        ↓↓↓ PIPELINE TRIGGERS AUTOMATICALLY ↓↓↓


┌─────────────────────────────────────────────────────────────────────┐
│                     PIPELINE EXECUTION                               │
└─────────────────────────────────────────────────────────────────────┘

╔═══════════════════════════════════════════════════════════════════╗
║  JOB 1: 📝 SUMMARIZE CHANGES (runs immediately)                   ║
╚═══════════════════════════════════════════════════════════════════╝

    ┌─────────────────────────────────────┐
    │  1. Checkout code from repository    │
    └──────────────┬──────────────────────┘
                   ↓
    ┌─────────────────────────────────────┐
    │  2. Compare changed files            │
    │     - Check for .cls (Apex)          │
    │     - Check for lwc/ (Lightning)     │
    │     - Check for .xml (Metadata)      │
    └──────────────┬──────────────────────┘
                   ↓
    ┌─────────────────────────────────────┐
    │  3. Post comment on PR               │
    │                                      │
    │  📊 Changes Summary:                 │
    │  ✅ Apex Classes                     │
    │  ✅ Lightning Components             │
    │  ⚪ Metadata                         │
    └──────────────┬──────────────────────┘
                   ↓
              JOB COMPLETE ✅


╔═══════════════════════════════════════════════════════════════════╗
║  JOB 2: ✅ VALIDATE DEPLOYMENT (runs after Job 1)                ║
╚═══════════════════════════════════════════════════════════════════╝

    ┌─────────────────────────────────────┐
    │  1. Checkout code                    │
    └──────────────┬──────────────────────┘
                   ↓
    ┌─────────────────────────────────────┐
    │  2. Setup Node.js environment        │
    │     - Install Node.js v18            │
    └──────────────┬──────────────────────┘
                   ↓
    ┌─────────────────────────────────────┐
    │  3. Install Salesforce CLI           │
    │     npm install -g @salesforce/cli   │
    └──────────────┬──────────────────────┘
                   ↓
    ┌─────────────────────────────────────┐
    │  4. Authenticate to Salesforce       │
    │     - Use JWT (JSON Web Token)       │
    │     - Uses secrets from GitHub:      │
    │       * SF_JWT_KEY                   │
    │       * SF_CONSUMER_KEY              │
    │       * SF_USERNAME                  │
    │       * SF_INSTANCE_URL              │
    └──────────────┬──────────────────────┘
                   ↓
    ┌─────────────────────────────────────┐
    │  5. Validate deployment              │
    │     sf project deploy start          │
    │       --dry-run (test only!)         │
    │       --test-level RunLocalTests     │
    │       --wait 30                      │
    │                                      │
    │  This runs ALL tests but doesn't     │
    │  actually deploy anything!           │
    └──────────────┬──────────────────────┘
                   ↓
           ┌───────┴────────┐
           ↓                ↓
    ┌──────────┐    ┌──────────────┐
    │ SUCCESS  │    │   FAILURE    │
    │    ✅    │    │      ❌      │
    └─────┬────┘    └──────┬───────┘
          ↓                ↓
    ┌─────────────────────────────────────┐
    │  6. Post validation results on PR    │
    │                                      │
    │  ✅ Validation Passed!               │
    │  (or ❌ Validation Failed)           │
    │                                      │
    │  View logs for details →             │
    └──────────────────────────────────────┘

    IF VALIDATION FAILS ❌
      └─> Developer fixes code
          └─> Push new commit
              └─> Pipeline runs again

    IF VALIDATION PASSES ✅
      └─> Ready to merge!


╔═══════════════════════════════════════════════════════════════════╗
║  WAITING FOR MERGE...                                             ║
║  (Pipeline pauses here until PR is merged)                        ║
╚═══════════════════════════════════════════════════════════════════╝

Developer or Reviewer clicks "Merge Pull Request"
                   ↓
        PR merged to main branch!
                   ↓

╔═══════════════════════════════════════════════════════════════════╗
║  JOB 3: 🚀 DEPLOY TO SALESFORCE (runs only after merge)          ║
╚═══════════════════════════════════════════════════════════════════╝

    ┌─────────────────────────────────────┐
    │  1. Checkout merged code             │
    └──────────────┬──────────────────────┘
                   ↓
    ┌─────────────────────────────────────┐
    │  2. Setup Node.js                    │
    └──────────────┬──────────────────────┘
                   ↓
    ┌─────────────────────────────────────┐
    │  3. Install Salesforce CLI           │
    └──────────────┬──────────────────────┘
                   ↓
    ┌─────────────────────────────────────┐
    │  4. Authenticate to Production       │
    │     - Can use different credentials  │
    │     - SF_PROD_* secrets              │
    │     - Falls back to SF_* if not set  │
    └──────────────┬──────────────────────┘
                   ↓
    ┌─────────────────────────────────────┐
    │  5. DEPLOY TO SALESFORCE! 🚀         │
    │     sf project deploy start          │
    │       (NO --dry-run, this is real!)  │
    │       --test-level RunLocalTests     │
    │       --wait 30                      │
    │                                      │
    │  Code is now LIVE in Salesforce!     │
    └──────────────┬──────────────────────┘
                   ↓
           ┌───────┴────────┐
           ↓                ↓
    ┌──────────┐    ┌──────────────┐
    │ SUCCESS  │    │   FAILURE    │
    │    ✅    │    │      ❌      │
    └─────┬────┘    └──────┬───────┘
          ↓                ↓
    ┌─────────────────────────────────────┐
    │  6. Post deployment results          │
    │                                      │
    │  🎉 Deployment Successful!           │
    │  Your changes are LIVE!              │
    │                                      │
    │  (or ❌ Deployment Failed)           │
    └──────────────────────────────────────┘

    IF DEPLOYMENT FAILS ❌
      └─> Notify team
          └─> Manual intervention needed
              └─> Fix and redeploy

    IF DEPLOYMENT SUCCEEDS ✅
      └─> Changes are live in Salesforce! 🎉


┌─────────────────────────────────────────────────────────────────────┐
│                         END OF PIPELINE                              │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Key Concepts Explained

### What is a "Pull Request" (PR)?
A Pull Request is a way to propose changes to the main codebase. Think of it as:
- "Hey team, I made some changes. Can you review them before we add them to the main code?"
- It allows for code review and automated testing BEFORE merging

### What does "Validate" mean?
Validation = Testing if your code CAN be deployed, without actually deploying it
- Like a practice run or dress rehearsal
- If validation fails, nothing breaks in Salesforce
- You can fix issues before they go live

### What does "Deploy" mean?
Deploy = Actually putting your code into Salesforce
- This makes your changes LIVE and visible to users
- Only happens AFTER the PR is merged
- Can't be easily undone, so we validate first!

### What is "JWT Authentication"?
JWT = A secure way for GitHub to connect to Salesforce without storing passwords
- Uses cryptographic keys (like a super-secure password)
- More secure than username/password
- Required for automated deployments

---

## 📊 Pipeline States

### 🟢 GREEN (Success)
All steps passed! Safe to merge/deploy.

### 🔴 RED (Failure)
Something went wrong. Check logs to see what failed.

### 🟡 YELLOW (In Progress)
Pipeline is currently running. Wait for it to complete.

### ⚪ GRAY (Skipped)
Step was skipped (e.g., deployment skipped if not merged)

---

## ⏱️ Typical Timeline

- **Summarize Changes:** ~30 seconds
- **Validate Deployment:** ~5-15 minutes (depends on test count)
- **Deploy to Salesforce:** ~5-15 minutes (depends on org and test count)

**Total time from PR creation to deployment:** ~20-40 minutes

---

## 🔒 Security Notes

### What secrets are used and why?

1. **SF_JWT_KEY** - Your private encryption key
   - WHY: Proves you're authorized to deploy to Salesforce
   - SECURITY: Never share this! Never commit to Git!

2. **SF_CONSUMER_KEY** - Your Connected App ID
   - WHY: Identifies which app is connecting to Salesforce
   - SECURITY: Not super secret, but don't share publicly

3. **SF_USERNAME** - Salesforce user account
   - WHY: Which Salesforce user to authenticate as
   - SECURITY: Should be a dedicated integration user

4. **SF_INSTANCE_URL** - Your Salesforce org URL
   - WHY: Tells the CLI which Salesforce instance to connect to
   - SECURITY: Not secret, but should be correct!

### Where are secrets stored?

- **GitHub Secrets:** Encrypted storage in GitHub
  - Only GitHub Actions can access them
  - Never visible in logs
  - Can't be read once saved (only updated)

- **NOT in your code:** Never write secrets in .yml files!
  - ✅ Good: `${{ secrets.SF_USERNAME }}`
  - ❌ Bad: `admin@mycompany.com`

---

## 🚦 When Does Each Job Run?

| Job | Trigger | Condition |
|-----|---------|-----------|
| **Summarize** | PR opened/updated | Always |
| **Validate** | After Summarize | Always |
| **Deploy** | PR merged to main | Only if merged |

### Manual Trigger

You can also run the workflow manually:
1. Go to Actions tab
2. Select "Salesforce CI/CD Pipeline"
3. Click "Run workflow"
4. Choose options and run

---

## 💡 Pro Tips

1. **Test in Sandbox First**
   - Always use a sandbox org for validation
   - Only deploy to production after testing

2. **Keep PRs Small**
   - Smaller changes = faster validation
   - Easier to review and fix issues

3. **Write Good Commit Messages**
   - Helps understand what changed in the summary
   - Example: `feat: add email validation to Contact trigger`

4. **Monitor the Pipeline**
   - Check GitHub Actions tab regularly
   - Read failure logs carefully
   - Fix issues promptly

5. **Use Branches**
   - Never commit directly to main
   - Always use feature branches
   - Example: `feature/add-new-field`, `bugfix/fix-validation`

---

## 🎓 Learning Resources

### Beginner Topics to Learn:
1. **Git Basics** - Branches, commits, pull requests
2. **YAML Syntax** - How to read .yml files
3. **Salesforce CLI** - Basic commands
4. **Salesforce Metadata** - What gets deployed
5. **Test Classes** - How to write Apex tests

### Recommended Order:
1. Read this guide thoroughly
2. Set up the pipeline following CICD-SETUP-GUIDE.md
3. Test with a small change
4. Learn from the logs
5. Gradually make bigger changes

---

Good luck with your CI/CD journey! 🚀
