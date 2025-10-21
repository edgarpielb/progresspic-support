Run xcodebuild to check for errors and warnings in the ProgressPic project, then fix all issues you find.

Steps:
1. Run xcodebuild with destination 'platform=iOS Simulator,name=iPhone 17 Pro' to build the project and capture all errors and warnings
2. Analyze the build output to identify all issues
3. Create a todo list with all errors and warnings that need to be fixed
4. Fix each issue systematically, marking todos as you complete them
5. Run xcodebuild again to verify all issues are resolved
6. Continue fixing any remaining issues until the build is clean

Important:
- Use the TodoWrite tool to track all errors and warnings
- Fix errors before warnings
- Mark each todo as in_progress when starting, and completed when done
- Verify the build succeeds with no errors or warnings at the end
- Always use destination 'platform=iOS Simulator,name=iPhone 17 Pro' for builds
