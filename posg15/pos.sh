#!/bin/bash

# ==================== CONFIGURATION ====================
SOURCE_HOST="localhost"
SOURCE_DB="datahub"
SOURCE_USERNAME="ygarzon"
# WARNING: Storing passwords in plain text is a security risk.
SOURCE_PASSWORD="your_pass_here" # check pass 

TARGET_HOST="localhost"
TARGET_DB="postgres" # The DB to restore INTO. Schemas will be created inside this DB.
TARGET_USERNAME="postgres"
# WARNING: Storing passwords in plain text is a security risk.
TARGET_PASSWORD="postgres"
TARGET_PORT="5466"

# -- Specify the exact schemas you want to migrate --
SCHEMAS_TO_MIGRATE=("merchant" "hubspot" "reference" "newaccount")
# =======================================================


# Set script to exit on any error
set -e
set -o pipefail

# --- Colors and print functions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Temp directory and cleanup ---
TEMP_DIR=$(mktemp -d)
print_status "Created temporary directory: $TEMP_DIR"
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Path for the dump
DUMP_DIR="$TEMP_DIR/selective_schema_dump"
mkdir -p "$DUMP_DIR"

# Determine the number of available CPU cores
PARALLEL_JOBS=$(nproc 2>/dev/null || echo 4)
print_status "Using up to $PARALLEL_JOBS parallel jobs."

print_status "Starting PostgreSQL SELECTIVE SCHEMA migration..."
print_status "Source: $SOURCE_USERNAME@$SOURCE_HOST/$SOURCE_DB"
print_status "Target: $TARGET_USERNAME@$TARGET_HOST:$TARGET_PORT/$TARGET_DB"
print_status "Schemas to be migrated: ${SCHEMAS_TO_MIGRATE[*]}"

# === SOURCE DATABASE OPERATIONS ===
export PGPASSWORD="$SOURCE_PASSWORD"

# Step 1: Build the pg_dump flags for the specific schemas
PG_DUMP_SCHEMA_FLAGS=""
for schema in "${SCHEMAS_TO_MIGRATE[@]}"; do
    PG_DUMP_SCHEMA_FLAGS+=" --schema=$schema"
done

# Step 2: Export schemas, EXCLUDING owners and permissions (ACLs)
print_status "Exporting schemas in parallel..."
print_warning "Stripping all owner and permission (GRANT/REVOKE) information from the dump."
pg_dump -h "$SOURCE_HOST" -U "$SOURCE_USERNAME" -d "$SOURCE_DB" \
        --format=directory \
        --jobs="$PARALLEL_JOBS" \
        --no-owner \
        --no-acl \
        $PG_DUMP_SCHEMA_FLAGS \
        -f "$DUMP_DIR"

if [ $? -eq 0 ]; then
    print_status "Selected schemas exported successfully to $DUMP_DIR"
else
    print_error "Failed to export from source database"
    exit 1
fi

# === TARGET DATABASE OPERATIONS ===
export PGPASSWORD="$TARGET_PASSWORD"

# Step 3: Clean up old schemas on the target to make the script re-runnable
print_status "Cleaning up target database by dropping old schemas (if they exist)..."
for schema in "${SCHEMAS_TO_MIGRATE[@]}"; do
    print_warning "Dropping schema '$schema' from target database '$TARGET_DB'..."
    psql -h "$TARGET_HOST" -p "$TARGET_PORT" -U "$TARGET_USERNAME" -d "$TARGET_DB" -c "DROP SCHEMA IF EXISTS \"$schema\" CASCADE;"
done

# Step 4: Restore the schemas into the target database
# We still use --no-owner and --no-acl here as a best practice,
# even though the data is already stripped from the dump.
print_status "Connecting to target and starting restore..."
pg_restore -h "$TARGET_HOST" -p "$TARGET_PORT" -U "$TARGET_USERNAME" -d "$TARGET_DB" \
           --no-owner \
           --no-acl \
           --jobs="$PARALLEL_JOBS" \
           -e \
           --verbose \
           "$DUMP_DIR"

if [ $? -eq 0 ]; then
    print_status "Schemas restored successfully to '$TARGET_DB'"
else
    print_error "Failed to restore schemas. Check pg_restore output above."
    exit 1
fi

# Step 5: Verification
# ... (verification code is fine) ...
VERIFY_SCHEMA="merchant"
print_status "Verifying migration for schema '$VERIFY_SCHEMA'..."
export PGPASSWORD="$SOURCE_PASSWORD"
SOURCE_TABLES=$(psql -h "$SOURCE_HOST" -U "$SOURCE_USERNAME" -d "$SOURCE_DB" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$VERIFY_SCHEMA' AND table_type='BASE TABLE';")
export PGPASSWORD="$TARGET_PASSWORD"
TARGET_TABLES=$(psql -h "$TARGET_HOST" -p "$TARGET_PORT" -U "$TARGET_USERNAME" -d "$TARGET_DB" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$VERIFY_SCHEMA' AND table_type='BASE TABLE';")

print_status "Migration Summary (for schema '$VERIFY_SCHEMA'):"
echo "  Source Tables: $SOURCE_TABLES, Target Tables: $TARGET_TABLES"
if [ "$SOURCE_TABLES" -eq "$TARGET_TABLES" ]; then
    print_status "✅ Table counts match. Migration likely successful!"
else
    print_warning "⚠️  Migration completed with object count differences. Please verify manually."
fi