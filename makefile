EXEC= aura
install:
	cp aura.sh "$HOME"/.local/bin/$(EXEC)
	chmod +x "$HOME"/.local/bin/$(EXEC)
