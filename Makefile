.PHONY: observe observe-test

# Rebuild the Session Store from all transcripts and open the dashboard.
# See docs/adr/0001 and observation/README.md.
observe:
	python3 observation/collect.py

# Run the transcript-parser regression test.
observe-test:
	python3 observation/test_parse.py
