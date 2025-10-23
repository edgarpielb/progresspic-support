Run xcodebuild to check for errors and warnings in the ProgressPic project, then fix all issues you find.

Steps:
1. Run xcodebuild with destination 'platform=iOS Simulator,name=iPhone 17 Pro' to build the project and save full output to /tmp/build_output.txt
2. Extract ALL warnings from the build output using: `grep -E "warning:" /tmp/build_output.txt`
3. Extract ALL errors from the build output using: `grep -E "error:" /tmp/build_output.txt`
4. Analyze the errors and warnings to identify all issues (ignore informational appintentsmetadataprocessor warnings)
5. Create a todo list with all errors and warnings that need to be fixed
6. Fix each issue systematically, marking todos as you complete them
7. Run xcodebuild again to verify all issues are resolved
8. Continue fixing any remaining issues until the build is clean

Important:
- ALWAYS save build output to a file with `tee /tmp/build_output.txt` to ensure warnings aren't missed
- ALWAYS use `grep -E "warning:" /tmp/build_output.txt` to extract all warnings from the saved output
- Ignore warnings from appintentsmetadataprocessor (these are informational only)
- Use the TodoWrite tool to track all errors and warnings
- Fix errors before warnings
- Mark each todo as in_progress when starting, and completed when done
- Verify the build succeeds with no errors or warnings at the end
- Always use destination 'platform=iOS Simulator,name=iPhone 17 Pro' for builds
