.PHONY: observe observe-test classify

# Print the product/factory classification from install-manifest.json (the
# single source of truth for what installs into a target vs what stays here).
classify:
	@./scripts/classify.sh

# Rebuild the Session Store from all transcripts and open the dashboard.
# See docs/adr/0001 and observation/README.md.
observe:
	python3 observation/collect.py

# Run the transcript-parser regression test.
observe-test:
	python3 observation/test_parse.py
