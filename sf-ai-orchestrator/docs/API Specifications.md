# API Specifications

This document describes the REST API endpoints hosted on Vercel (Next.js) that Salesforce can call out to for saving and retrieving data stored in MongoDB.

---

## Base URL

```
https://<your-vercel-domain>.vercel.app
```

---

## Authentication

All endpoints require an API key passed as a request header.

| Header      | Value                  |
|-------------|------------------------|
| `x-api-key` | `<SALESFORCE_API_KEY>` |

The API key must match the `SALESFORCE_API_KEY` environment variable configured in Vercel. Requests without a valid key will receive a `401 Unauthorized` response.

---

## Endpoints

### 1. Save Data

**`POST /api/salesforce/data`**

Saves a JSON payload from Salesforce into MongoDB.

#### Request

- **Method:** `POST`
- **Content-Type:** `application/json`
- **Headers:**
  ```
  x-api-key: <SALESFORCE_API_KEY>
  Content-Type: application/json
  ```
- **Body:** Any valid JSON object. Example:
  ```json
  {
    "sfId": "0015g00000XyzAbcAAF",
    "objectType": "Account",
    "name": "Acme Corp",
    "email": "contact@acme.com",
    "customField": "some value"
  }
  ```

#### Response

**201 Created** — Record saved successfully.
```json
{
  "success": true,
  "id": "64f1a2b3c4d5e6f7a8b9c0d1"
}
```

**400 Bad Request** — Body is missing or not a JSON object.
```json
{
  "error": "Invalid JSON body"
}
```

**401 Unauthorized** — Missing or invalid API key.
```json
{
  "error": "Unauthorized"
}
```

**500 Internal Server Error** — Database error.
```json
{
  "error": "Database error"
}
```

---

### 2. Get Data

**`GET /api/salesforce/data`**

Retrieves records from MongoDB. Supports filtering by Salesforce record ID and pagination.

#### Request

- **Method:** `GET`
- **Headers:**
  ```
  x-api-key: <SALESFORCE_API_KEY>
  ```
- **Query Parameters:**

  | Parameter | Type   | Required | Default | Description                              |
  |-----------|--------|----------|---------|------------------------------------------|
  | `sfId`    | string | No       | —       | Filter records by Salesforce record ID   |
  | `limit`   | number | No       | `50`    | Max records to return (capped at `200`)  |
  | `skip`    | number | No       | `0`     | Number of records to skip (for paging)   |

#### Response

**200 OK** — Records retrieved successfully.
```json
{
  "success": true,
  "total": 2,
  "records": [
    {
      "_id": "64f1a2b3c4d5e6f7a8b9c0d1",
      "sfId": "0015g00000XyzAbcAAF",
      "objectType": "Account",
      "name": "Acme Corp",
      "createdAt": "2024-09-01T10:00:00.000Z",
      "updatedAt": "2024-09-01T10:00:00.000Z"
    }
  ]
}
```

**401 Unauthorized** — Missing or invalid API key.
```json
{
  "error": "Unauthorized"
}
```

**500 Internal Server Error** — Database error.
```json
{
  "error": "Database error"
}
```

---

## Salesforce Setup Guide

### Step 1 — Add the Vercel domain to Remote Site Settings

1. In Salesforce, go to **Setup → Security → Remote Site Settings**.
2. Click **New Remote Site**.
3. Enter a name (e.g. `VercelAPI`) and the URL `https://<your-vercel-domain>.vercel.app`.
4. Save.

### Step 2 — Store the API Key in a Custom Setting or Named Credential

Store `SALESFORCE_API_KEY` securely:
- **Option A (Named Credential):** Create a Named Credential with the base URL and add the `x-api-key` header as a custom header.
- **Option B (Custom Setting/Custom Metadata):** Store the key in a Protected Custom Setting and reference it in Apex.

### Step 3 — Apex Callout Examples

#### Save data (POST)

```apex
HttpRequest req = new HttpRequest();
req.setEndpoint('https://<your-vercel-domain>.vercel.app/api/salesforce/data');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setHeader('x-api-key', '<SALESFORCE_API_KEY>');

Map<String, Object> payload = new Map<String, Object>{
    'sfId'       => '0015g00000XyzAbcAAF',
    'objectType' => 'Account',
    'name'       => 'Acme Corp'
};
req.setBody(JSON.serialize(payload));

Http http = new Http();
HttpResponse res = http.send(req);

if (res.getStatusCode() == 201) {
    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    System.debug('Saved with id: ' + result.get('id'));
} else {
    System.debug('Error: ' + res.getBody());
}
```

#### Get data (GET)

```apex
HttpRequest req = new HttpRequest();
req.setEndpoint('https://<your-vercel-domain>.vercel.app/api/salesforce/data?sfId=0015g00000XyzAbcAAF');
req.setMethod('GET');
req.setHeader('x-api-key', '<SALESFORCE_API_KEY>');

Http http = new Http();
HttpResponse res = http.send(req);

if (res.getStatusCode() == 200) {
    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    List<Object> records = (List<Object>) result.get('records');
    System.debug('Total: ' + result.get('total'));
    System.debug('Records: ' + records);
} else {
    System.debug('Error: ' + res.getBody());
}
```

---

## Environment Variables (Vercel)

Configure these in your Vercel project settings under **Settings → Environment Variables**:

| Variable             | Description                                      |
|----------------------|--------------------------------------------------|
| `MONGODB_URI`        | MongoDB connection string                        |
| `MONGODB_DB_NAME`    | MongoDB database name (default: `salesforce`)    |
| `SALESFORCE_API_KEY` | Shared secret key used to authenticate Salesforce callouts |
