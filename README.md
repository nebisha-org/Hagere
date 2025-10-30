# AgereLige Flutter Client

A minimal Flutter client that reuses your existing AWS Chalice backend.

## Backend contracts (from `app.py`)

- `POST /upload-url` -> `{"uploadURL": "<presigned PUT>", "fileKey": "user-images/<uuid>.jpg"}`
- `POST /users` with body:
  ```json
  {
    "name": "string",
    "age": "string",
    "gender": "string",
    "bio": "string",
    "imageUrl": "string (S3 key)",
    "latitude": "string",
    "longitude": "string",
    "city": "string",
    "state": "string"
  }
  ```
  returns `{"user_id": "<uuid>"}`
- `GET /users` -> `{"users": [ {User} ]}`
- `GET /users/{user_id}` -> `{User}` or `{}`

Where `{User}` uses DynamoDB JSON keys:
`UserID, Name, Age, Gender, Bio, ImageUrl, Latitude, Longitude, City, State`

## Run

```
flutter pub get
flutter run
```

The sample UI lets you:
- List users
- Create a "Guest" user
- Upload a tiny JPEG via the presigned URL, then create a user that references it
- Tap a row to fetch detail by `UserID`
