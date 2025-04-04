-include .env
-include ../../Makefile

lint:
	@forge fmt --check && npx solhint "{script,src,test}/**/*.sol"

lint-fix:
	@forge fmt && npx solhint --fix "{script,src,test}/**/*.sol" --fix --noPrompt --disc
