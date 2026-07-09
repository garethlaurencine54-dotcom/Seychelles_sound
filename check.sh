#!/bin/bash
echo "--- Analyzing Code ---"
flutter analyze || exit 1
echo "--- Formatting Code ---"
dart format .
echo "--- Build Check Passed! Ready to push. ---"
