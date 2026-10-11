# run:
# 	clear && odin run .

run:
	clear && ./dir_diff

brun:
	odin build . && clear && ./dir_diff

run-debug:
	clear && make debug && ./debug_build-main_odin

build:
	odin build .

debug:
	odin build . -debug -o:none

clean:
	rm -rf ./debug_build-main_odin.dSYM ./dir_diff.dSYM ./dir-diff.dSYM ./debug_build-main_odin dir_diff debug_build-dir_diff_odin debug_build-dir_diff_odin.dSYM


git:
	git add -A && \
	printf "message: "; \
	read MESSAGE; \
	git commit -m "$$MESSAGE" && \
	git push
