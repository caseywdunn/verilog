# Makefile for Tiny Thumb-1 Core on DE10-Nano
# Requires Intel Quartus Prime installed and in PATH

PROJECT = de10nano_top
TOP = de10nano_top

# Quartus tools
QUARTUS_MAP = quartus_map
QUARTUS_FIT = quartus_fit
QUARTUS_ASM = quartus_asm
QUARTUS_STA = quartus_sta
QUARTUS_PGM = quartus_pgm

# Output files
SOF_FILE = output_files/$(PROJECT).sof
RBF_FILE = output_files/$(PROJECT).rbf

.PHONY: all clean map fit asm sta program program-sof help

all: $(SOF_FILE)

help:
	@echo "Makefile for Tiny Thumb-1 Core on DE10-Nano"
	@echo ""
	@echo "Targets:"
	@echo "  all         - Full synthesis flow (map, fit, asm, sta)"
	@echo "  map         - Analysis & Synthesis only"
	@echo "  fit         - Fitter only"
	@echo "  asm         - Assembler only (generate .sof)"
	@echo "  sta         - Static Timing Analysis only"
	@echo "  program-sof - Program FPGA with .sof file (temporary, lost on power cycle)"
	@echo "  rbf         - Generate .rbf file (for MiSTer or flash programming)"
	@echo "  clean       - Remove all generated files"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Before synthesis, ensure prog.hex is up to date:"
	@echo "  cp ../prog.hex .  (or link to desired test)"

map:
	$(QUARTUS_MAP) $(PROJECT)

fit: map
	$(QUARTUS_FIT) $(PROJECT)

asm: fit
	$(QUARTUS_ASM) $(PROJECT)

sta: fit
	$(QUARTUS_STA) $(PROJECT)

$(SOF_FILE): asm sta
	@echo "Synthesis complete: $(SOF_FILE)"

# Generate RBF file for MiSTer or flash programming
rbf: $(RBF_FILE)

$(RBF_FILE): $(SOF_FILE)
	quartus_cpf -c $(SOF_FILE) $(RBF_FILE)
	@echo "RBF file generated: $(RBF_FILE)"

# Program the FPGA (temporary - lost on power cycle)
program-sof: $(SOF_FILE)
	$(QUARTUS_PGM) -m jtag -o "p;$(SOF_FILE)"

clean:
	rm -rf output_files db incremental_db
	rm -f *.rpt *.summary *.done *.smsg *.qws *.sld *.jdi
	@echo "Clean complete"

# Convenience: update program from parent directory
update-prog:
	cp ../prog.hex .
	@echo "Updated prog.hex from parent directory"
