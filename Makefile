.PHONY: quality quality-lint quality-types quality-unit quality-integration quality-property quality-contract quality-mutation quality-app-security quality-supply-chain

quality: quality-lint quality-types quality-unit quality-integration quality-property quality-contract quality-mutation quality-app-security quality-supply-chain

quality-lint:
	mix format --check-formatted
	mix credo --min-priority high

quality-types:
	MIX_ENV=test mix compile --warnings-as-errors
	MIX_ENV=test mix dialyzer

quality-unit:
	MIX_ENV=test mix test --exclude integration --exclude property --exclude contract

quality-integration:
	MIX_ENV=test mix test --only integration

quality-property:
	MIX_ENV=test mix test --only property

quality-contract:
	MIX_ENV=test mix test --only contract

quality-mutation:
	./scripts/ci/run-mutation.sh

quality-app-security:
	./scripts/ci/run-semgrep.sh && ./scripts/ci/scan-long-base64-literals.sh

quality-supply-chain:
	mix hex.audit && ./scripts/ci/run-osv-scanner.sh && ./scripts/ci/run-trivy.sh && ./scripts/ci/run-trivy-app-secrets.sh
