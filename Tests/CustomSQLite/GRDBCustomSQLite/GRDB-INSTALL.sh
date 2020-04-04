# The path to the folder containing GRDBCustom.xcodeproj:
GRDB_SOURCE_PATH="${PROJECT_DIR}/GRDB"

# The path to your custom "SQLiteLib-USER.xcconfig":
SQLITELIB_XCCONFIG_USER_PATH="${PROJECT_DIR}/GRDBCustomSQLite/SQLiteLib-USER.xcconfig"

# The path to your custom "GRDB-USER.xcconfig":
CUSTOMSQLITE_XCCONFIG_USER_PATH="${PROJECT_DIR}/GRDBCustomSQLite/GRDB-USER.xcconfig"

# The path to your custom "GRDB-USER.h":
CUSTOMSQLITE_H_USER_PATH="${PROJECT_DIR}/GRDBCustomSQLite/GRDB-USER.h"

#######################################################
#
#######################################################


if [ ! -d "$GRDB_SOURCE_PATH" ];
then
echo "error: Path to GRDB source (GRDB_SOURCE_PATH) missing/incorrect: $GRDB_SOURCE_PATH"
exit 1
fi

SyncFileChanges () {
    SOURCE=$1
    DESTINATIONPATH=$2
    DESTINATIONFILENAME=$3
    DESTINATION="${DESTINATIONPATH}/${DESTINATIONFILENAME}"
    
    if [ ! -f "$SOURCE" ];
    then
    echo "error: Source file missing: $SOURCE"
    exit 1
    fi
    
    rsync -a "$SOURCE" "$DESTINATION"
}

SyncFileChanges $SQLITELIB_XCCONFIG_USER_PATH "${GRDB_SOURCE_PATH}/SQLiteCustom/src" "SQLiteLib-USER.xcconfig"
SyncFileChanges $CUSTOMSQLITE_XCCONFIG_USER_PATH "${GRDB_SOURCE_PATH}/SQLiteCustom" "GRDB-USER.xcconfig"
SyncFileChanges $CUSTOMSQLITE_H_USER_PATH "${GRDB_SOURCE_PATH}/SQLiteCustom" "GRDB-USER.h"

echo "Finished syncing"
