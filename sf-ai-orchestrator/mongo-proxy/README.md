# mongo-proxy

Thin REST proxy that bridges Salesforce HTTP callouts to MongoDB Atlas.

## Why this exists

Salesforce can only make **outbound HTTPS callouts** — it cannot host servers or use native drivers (TCP). MongoDB requires a driver connection. This Lambda proxy sits between them:

```
Salesforce Apex  →  HTTPS POST  →  API Gateway + Lambda  →  MongoDB Driver  →  Atlas Cluster
```

It accepts the same JSON body shape that the deprecated Atlas Data API used, so `MongoDBLogService.cls` requires minimal changes.

## Structure

```
mongo-proxy/
├── src/
│   ├── handler.js    # Lambda entry point
│   ├── actions.js    # MongoDB action logic (insertOne, updateOne, find, aggregate)
│   ├── auth.js       # API key validation
│   └── db.js         # MongoDB client (connection pooling)
├── test/
│   ├── actions.test.js
│   └── auth.test.js
├── infra/
│   └── template.yaml # AWS SAM deployment template
└── package.json
```

## Local development

```bash
npm install

# Run tests
npm test

# Set env vars and invoke locally with SAM
cp .env.example .env   # fill in MONGODB_URI and API_KEY
sam local invoke MongoProxyFunction -e test/events/insertOne.json
```

## Deploy to AWS

### Prerequisites
- [AWS CLI](https://aws.amazon.com/cli/) configured
- [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html)
- Two secrets in AWS Secrets Manager:
  - `sf-mongo-proxy/mongodb-uri` — your Atlas connection string
  - `sf-mongo-proxy/api-key`     — a random secret key (Salesforce will send this)

### Steps

```bash
# 1. Store secrets
aws secretsmanager create-secret \
  --name sf-mongo-proxy/mongodb-uri \
  --secret-string "mongodb+srv://user:pass@cluster.mongodb.net"

aws secretsmanager create-secret \
  --name sf-mongo-proxy/api-key \
  --secret-string "$(openssl rand -hex 32)"

# 2. Build and deploy
sam build
sam deploy --guided   # follow prompts; note the API Gateway URL in outputs

# 3. Update Salesforce
#    - Named Credential AI_MongoDB_Atlas → set URL to the API Gateway output URL
#    - External Credential principal → set Password = your api-key value
#    - CMDT AI_MongoDB_Config__mdt.Default → set Is_Active__c = true
```

## API contract

All requests: `POST /action/{action}`
Required header: `X-Api-Key: <your-key>`

### Request body (all actions)

| Field        | Required | Description                  |
|---|---|---|
| `database`   | ✅        | MongoDB database name         |
| `collection` | ✅        | Collection name               |
| `dataSource` | optional  | Ignored (kept for compat)     |

### Actions

| Action       | Extra fields                          | Response                              |
|---|---|---|
| `insertOne`  | `document`                            | `{ insertedId }`                      |
| `updateOne`  | `filter`, `update`, `arrayFilters?`   | `{ matchedCount, modifiedCount }`     |
| `find`       | `filter?`, `projection?`, `sort?`, `limit?` | `{ documents[] }`              |
| `aggregate`  | `pipeline`                            | `{ documents[] }`                     |

## Environment variables

| Variable      | Description                                      |
|---|---|
| `MONGODB_URI` | MongoDB connection string                        |
| `API_KEY`     | Secret key checked in `X-Api-Key` request header |
