run:
	odin run .

run-debug:
	make debug && ./debug_build-main_odin

build:
	odin build . -out:dir_diff

debug:
	odin build . -debug -out:debug_build-main_odin

clean: 
	rm -rf ./debug_build-main_odin.dSYM ./dir-diff.dSYM ./debug_build-main_odin


git:
	git add -A && \
	printf "message: "; \
	read MESSAGE; \
	git commit -m "$$MESSAGE" && \
	git push