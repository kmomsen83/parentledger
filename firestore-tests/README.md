# Firestore Rules Tests

## Prerequisites

- Firebase CLI installed
- Java runtime available (for Firestore emulator)

## Install

```bash
cd firestore-tests
npm install
```

## Run tests

From repo root:

```bash
firebase emulators:exec --only firestore "npm --prefix firestore-tests test"
```

## Covered critical cases

- Unauthorized case access -> denied
- Unauthorized membership write (`memberIds`) -> denied
- Valid post-invite membership read -> allowed
- Non-member read -> denied

