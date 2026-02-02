VERILATOR ?= verilator
TOP       ?= mlp_tb
OBJDIR    ?= obj_dir

SV_SRCS = \
	mlp_tb.sv \
	layer.sv \
	mac_unit.sv \
	relu.sv \
	bram.sv

SV_INC = -I.
SV_FLAGS = -sv --binary --timing -Mdir $(OBJDIR)

all: sim

sim:
	$(VERILATOR) $(SV_FLAGS) $(SV_INC) $(SV_SRCS)

run: sim
	./$(OBJDIR)/V$(TOP)

clean:
	rm -rf $(OBJDIR)

.PHONY: all sim run clean
