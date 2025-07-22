#!/bin/bash

# Taskwarrior <-> taskchamp sync script
# Usage: ./sync-taskwarrior.sh [export|import]

set -e

# Configuration
TASKDATA=${TASKDATA:-~/.task}
TASKCHAMP_DB="$HOME/Documents/taskchamp-sync.sqlite3"
TEMP_JSON="/tmp/taskwarrior-export.json"

case "${1:-help}" in
  export)
    echo "Exporting Taskwarrior tasks to JSON..."
    task export > "$TEMP_JSON"
    echo "Exported $(jq '. | length' "$TEMP_JSON") tasks to $TEMP_JSON"
    echo
    echo "Manual steps:"
    echo "1. Copy $TEMP_JSON to your development machine"
    echo "2. Import into taskchamp SQLite database"
    echo "3. Copy database to iOS app via iTunes/Finder file sharing"
    ;;
  
  import)
    echo "Import functionality would read from taskchamp SQLite and update Taskwarrior"
    echo "This requires implementing SQLite -> Taskwarrior conversion"
    echo "For now, use 'task import' with JSON exports from the app"
    ;;
  
  info)
    echo "=== Taskwarrior Info ==="
    echo "Version: $(task --version)"
    echo "Data location: $TASKDATA"
    echo "Task count: $(task count)"
    echo
    echo "=== taskchamp Database ==="
    if [ -f "$TASKCHAMP_DB" ]; then
      echo "Database: $TASKCHAMP_DB (exists)"
      echo "Task count: $(sqlite3 "$TASKCHAMP_DB" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "N/A")"
    else
      echo "Database: $TASKCHAMP_DB (not found)"
    fi
    ;;
  
  *)
    echo "Taskwarrior <-> taskchamp sync utility"
    echo
    echo "Usage: $0 [export|import|info]"
    echo
    echo "Commands:"
    echo "  export  - Export Taskwarrior tasks to JSON"
    echo "  import  - Import taskchamp tasks to Taskwarrior (TODO)"
    echo "  info    - Show sync status and database info"
    echo
    echo "Current sync method: Manual JSON export/import"
    echo "Future: Direct SQLite database sync when TaskChampion is stable"
    ;;
esac