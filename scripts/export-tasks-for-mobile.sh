#!/bin/bash
# Export Taskwarrior tasks for TaskChamp mobile import

echo "Exporting Taskwarrior tasks for mobile import..."

# Export all tasks to JSON
task export > ~/tasks.json

echo "✅ Exported $(task count) tasks to ~/tasks.json"
echo ""
echo "Next steps:"
echo "1. Copy tasks.json to your iPhone using AirDrop or Files app"
echo "2. In Files app, move it to: On My iPhone > TaskChamp > tasks.json"
echo "3. Open TaskChamp and run AWS sync"
echo "4. The app will import all your desktop tasks"