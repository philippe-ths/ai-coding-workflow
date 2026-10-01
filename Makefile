.PHONY: observe observe-test classify upkeep upkeep-dry upkeep-report

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

# Choose one project for upkeep now and run aiw-upkeep in it, if both quota gates pass.
# See upkeep/scheduler.py; upkeep/install-upkeep.sh adds the weekday 22:00 timer.
upkeep:
	python3 upkeep/scheduler.py run

# Show which project upkeep would choose, and why, without running anything.
upkeep-dry:
	python3 upkeep/scheduler.py run --dry-run

# The recent upkeep decisions, broken mains, and open close proposals.
upkeep-report:
	python3 upkeep/scheduler.py report
