# Style Guidelines

Please ensure that your code adheres to the following style guidelines:

## Ruby Style

- Follow the conventions defined by RuboCop for Ruby code.
- Make sure there are no RuboCop offenses in your code. You can run `rubocop -A` locally to check for offenses and fix them before submitting your pull request.

## Security

- Check for security vulnerabilities using `bundle audit` and `brakeman`.
- Ensure there are no critical security issues reported by these tools in your changes.
- If any security issues are found, address them before submitting your pull request.

## Testing

- Add tests to cover your changes and make sure that existing tests pass.
- Run the test suite locally to verify that your changes do not introduce new test failures.

## Documentation

- Update documentation as needed to reflect any changes in behavior or functionality.
- Ensure that code comments are clear and helpful, especially in complex or non-obvious sections of the code.

## Code Cleanliness

- Keep your code clean and organized.
- Follow the Single Responsibility Principle (SRP) and keep methods and classes focused on doing one thing well.
- Use meaningful variable and method names.
- Avoid unnecessary duplication.
- Remove commented-out code and debug statements.

## Commit Messages

- Write clear and descriptive commit messages that explain the purpose of each commit.
- Use meaningful commit message prefixes such as "Fix," "Feature," "Refactor," or "Docs."

## Code Review

- Be open to feedback during the code review process.
- Respond promptly to comments and questions from reviewers.
- Address any concerns or suggestions raised by reviewers.

By following these style guidelines, you help maintain code quality, security, and readability in our project.

Thank you for your contributions! :heart: :heart:
