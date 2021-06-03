OUT_FILE = Greybox.rbxlx

SRC = Greybox

ROJO = rojo
ROJO_PROJECT_BUILD = default.project.json

$(OUT_FILE) : $(shell find $(SRC)) $(ROJO_PROJECT_BUILD)
	$(ROJO) build $(ROJO_PROJECT_BUILD) --output $(OUT_FILE)

clean :
	$(RM) $(OUT_FILE) $(CMDR)
