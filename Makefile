run:
	odin run .

build:
	odin build . -out:dir_diff

debug:
	odin build . -debug -out:debug_build-main_odin


git:
	git add -A && \
	printf "message: "; \
	read MESSAGE; \
	git commit -m "$$MESSAGE" && \
	git push