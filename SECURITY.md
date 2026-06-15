# Security Policy

## Reporting

Please do not open a public issue for vulnerabilities involving credentials,
privacy, arbitrary code execution, or release signing.

Report them privately through GitHub Security Advisories for this repository.
Include reproduction steps, affected macOS version, and the relevant commit.

## Secrets

MacVoice stores the OpenAI API key in macOS Keychain. The application does not
read a runtime key from `.env`, source files, or `UserDefaults`.

If a key is accidentally committed:

1. Revoke it immediately in the OpenAI dashboard.
2. Remove it from Git history.
3. Rotate any related credentials.
4. Notify maintainers through a private security report.

## Supported versions

Security fixes are provided for the latest released version of MacVoice.
